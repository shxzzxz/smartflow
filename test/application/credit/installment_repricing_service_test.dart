import '../../helper/legacy_installment_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/installment/command/installment_repricing_service.dart';
import 'package:smartflow/application/credit/installment/query/installment_query_service.dart';
import 'package:smartflow/application/credit/reference_rate/reference_rate_service.dart';
import 'package:smartflow/application/credit/task/installment_repricing_task.dart';
import 'package:smartflow/application/shared/task/app_task.dart';
import 'package:smartflow/domain/credit/port/reference_rate_source.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_reference_rate_repository.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/domain/credit/valobj/repayment_amount_breakdown.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';
import 'package:smartflow/application/credit/installment/command/installment_plan_service.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_terms.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/interest_rate.dart';
import 'package:smartflow/domain/credit/valobj/floating_rate.dart';
import 'package:smartflow/domain/credit/valobj/repayment_dates_strategy.dart';
import 'package:smartflow/domain/credit/service/installment/installment_plan_engine.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_change.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_operation.dart';
import 'package:smartflow/domain/credit/service/installment/installment_origination_service.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_bill_repository.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_repricing_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_repayment_repository.dart';
import 'package:smartflow/infrastructure/data_management/backup/drift_backup_gateway.dart';
import 'package:smartflow/application/data_management/backup/backup_service.dart';
import 'package:smartflow/application/data_management/backup/backup_models.dart';
import 'package:smartflow/application/data_management/backup/installment_backup_migration.dart';
import '../../helper/test_app_database.dart';

void main() {
  late _Fixture f;
  setUp(() async {
    f = _Fixture();
    await f.seed();
  });
  tearDown(() => f.db.close());

  test(
    'completed generation skips scans, retries pending application and reopens on extension',
    () async {
      f.currentDate = DateTime.utc(2026, 12, 20);
      await f.service.prepare('loan', DateTime.utc(2026, 12, 20));
      var contract = (await f.installments.findContract('loan'))!;
      expect(
        contract.repricingConfigurations.single.generationCompleted,
        isTrue,
      );
      final last = contract.repricingConfigurations.single.lastGeneratedDate;
      expect(last, DateTime.utc(2026, 9, 20));
      // 最后一条已生成，但应用失败仍必须被任务扫描和重试。
      await f.db.customStatement(
        "CREATE TRIGGER reject_completion_apply BEFORE UPDATE ON installment_repricing_records BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      expect(
        (await f.service.runDue(DateTime.utc(2026, 12, 20))).needsRetry,
        isTrue,
      );
      expect(await f.records.contractIdsForRepricing(), contains('loan'));
      await f.db.customStatement('DROP TRIGGER reject_completion_apply');
      expect(
        (await f.service.runDue(DateTime.utc(2026, 12, 20))).needsRetry,
        isFalse,
      );
      expect(
        await f.records.contractIdsForRepricing(),
        isNot(contains('loan')),
      );
      final records = await f.records.list('loan');
      await f.service.delete('loan', records.first.id);
      expect(
        await f.records.contractIdsForRepricing(),
        isNot(contains('loan')),
      );

      // 延长阶段重新检查配置，保持进度且不重建用户删除的结果。
      contract = (await f.installments.findContract('loan'))!;
      contract.reviseStageTerms(
        InstallmentContractTerms.singleStage(
          id: 'stage',
          totalPeriods: 24,
          firstDate: DateTime(2026, 1, 20),
          method: InstallmentRepaymentMethod.equalInstallment,
          accrual: InterestAccrualMethod.monthly,
          ratePeriod: InterestRatePeriod.annual,
          ratePpm: 48000,
        ),
      );
      await f.installments.saveAggregate(
        contract,
        await f.installments.listSchedules('loan'),
      );
      expect(await f.records.contractIdsForRepricing(), contains('loan'));
      contract = (await f.installments.findContract('loan'))!;
      expect(
        contract.repricingConfigurations.single.generationCompleted,
        isFalse,
      );
      expect(contract.repricingConfigurations.single.lastGeneratedDate, last);
      await f.service.prepare('loan', DateTime.utc(2026, 12, 20));
      final after = await f.records.list('loan');
      expect(after.any((r) => r.id == records.first.id), isFalse);
      expect(after.last.change.resetDate, DateTime.utc(2026, 12, 20));
    },
  );

  test(
    'deleting a successor reopens its predecessor without resetting progress',
    () async {
      f.currentDate = DateTime.utc(2026, 3, 20);
      await f.service.prepare('loan', DateTime.utc(2026, 1, 5));
      final before = (await f.installments.findContract(
        'loan',
      ))!.repricingConfigurations.single;
      await f.service.addConfiguration(
        'loan',
        stageId: 'stage',
        effectiveFrom: DateTime.utc(2026, 3, 20),
        rule: FloatingRateRule(
          referenceRateType: InterestRateType.lprFiveYearPlus,
          spreadBp: -30,
          firstResetDate: DateTime.utc(2026, 3, 20),
          firstEffectiveDate: DateTime.utc(2026, 4, 1),
          cycleMonths: 3,
        ),
      );
      var configurations = (await f.installments.findContract(
        'loan',
      ))!.repricingConfigurations;
      expect(configurations.first.generationCompleted, isTrue);
      expect(configurations.last.generationCompleted, isFalse);
      await f.service.deleteConfiguration('loan', configurations.last.id);
      configurations = (await f.installments.findContract(
        'loan',
      ))!.repricingConfigurations;
      expect(configurations.single.generationCompleted, isFalse);
      expect(configurations.single.lastGeneratedDate, before.lastGeneratedDate);
      await f.service.prepare('loan', DateTime.utc(2026, 3, 20));
      expect((await f.records.list('loan')).map((r) => r.change.resetDate), [
        DateTime.utc(2025, 12, 20),
        DateTime.utc(2026, 3, 20),
      ]);
    },
  );

  test(
    'last-period quote failure leaves generation open and final status is atomic',
    () async {
      f.currentDate = DateTime.utc(2026, 9, 20);
      await f.service.prepare('loan', DateTime.utc(2026, 6, 20));
      expect(
        await f.service.prepare(
          'loan',
          DateTime.utc(2026, 9, 20),
          resolvedRates: {},
        ),
        isFalse,
      );
      var config = (await f.installments.findContract(
        'loan',
      ))!.repricingConfigurations.single;
      expect(config.generationCompleted, isFalse);
      expect(config.lastGeneratedDate, DateTime.utc(2026, 6, 20));
      await f.db.customStatement(
        "CREATE TRIGGER reject_generation_completion BEFORE UPDATE OF generation_completed ON installment_repricing_configs WHEN NEW.generation_completed = 1 BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      await expectLater(
        f.service.prepare('loan', DateTime.utc(2026, 9, 20)),
        throwsException,
      );
      config = (await f.installments.findContract(
        'loan',
      ))!.repricingConfigurations.single;
      expect(config.generationCompleted, isFalse);
      expect(config.lastGeneratedDate, DateTime.utc(2026, 6, 20));
      expect(
        (await f.records.list('loan')).last.change.resetDate,
        DateTime.utc(2026, 6, 20),
      );
      await f.db.customStatement('DROP TRIGGER reject_generation_completion');
      await f.service.prepare('loan', DateTime.utc(2026, 9, 20));
      expect(
        (await f.installments.findContract(
          'loan',
        ))!.repricingConfigurations.single.generationCompleted,
        isTrue,
      );
    },
  );

  test(
    'pending repricing is applied even after its generating configuration is deleted',
    () async {
      expect(await f.service.prepare('loan', f.currentDate), isTrue);
      final contract = (await f.installments.findContract('loan'))!;
      expect(contract.repricings, isNotEmpty);
      expect(contract.repricings.every((r) => !r.applied), isTrue);
      await f.service.deleteConfiguration(
        'loan',
        contract.repricingConfigurations.single.id,
      );
      expect(await f.service.runDue(f.currentDate), (
        changed: true,
        needsRetry: false,
      ));
      final records = await f.records.list('loan');
      expect(records.map((r) => r.id), contract.repricings.map((r) => r.id));
      expect(records.every((r) => r.applied), isTrue);
    },
  );

  test(
    'deleting a configuration keeps generated rates and the saved plan',
    () async {
      await f.service.runDue(f.currentDate);
      final before = (await f.installments.findContract('loan'))!;
      final schedules = await f.installments.listSchedules('loan');
      expect(before.repricings, isNotEmpty);
      final configurationId = before.repricingConfigurations.single.id;

      await f.service.deleteConfiguration('loan', configurationId);
      var after = (await f.installments.findContract('loan'))!;
      expect(after.repricingConfigurations, isEmpty);
      expect(
        after.repricings.map((r) => (r.id, r.status, r.change.rate.ppm)),
        before.repricings.map((r) => (r.id, r.status, r.change.rate.ppm)),
      );
      expect(
        (await f.installments.listSchedules('loan')).map(
          (row) => (
            row.id,
            row.expectedPrincipal,
            row.expectedInterest,
            row.expectedFee,
          ),
        ),
        schedules.map(
          (row) => (
            row.id,
            row.expectedPrincipal,
            row.expectedInterest,
            row.expectedFee,
          ),
        ),
      );
      await f.service.runDue(DateTime.utc(2026, 12, 20));
      after = (await f.installments.findContract('loan'))!;
      expect(
        after.repricings.map((r) => r.id),
        before.repricings.map((r) => r.id),
      );
      await f.service.delete('loan', after.repricings.first.id);
      expect(
        (await f.records.list('loan')).length,
        before.repricings.length - 1,
      );
    },
  );

  test(
    'configuration deletion rejects an id belonging to another contract',
    () async {
      await f.seed(id: 'other');
      final other = (await f.installments.findContract('other'))!;
      await expectLater(
        f.service.deleteConfiguration(
          'loan',
          other.repricingConfigurations.single.id,
        ),
        throwsA(isA<BusinessException>()),
      );
      expect(
        (await f.installments.findContract('other'))!.repricingConfigurations,
        hasLength(1),
      );
    },
  );

  test(
    'configuration switch retains an earlier reset with a later effective date',
    () async {
      await f.seed(
        id: 'annual-scope',
        borrowingDate: DateTime.utc(2025, 6, 20),
        stageTerms: InstallmentContractTerms(
          stages: [
            InstallmentContractStage(
              id: 'annual-stage',
              terms: AmortizingStage(
                dates: IntervalRepaymentDates(
                  firstDate: DateTime.utc(2026, 6, 20),
                  count: 2,
                  intervalMonths: 12,
                ),
                method: InstallmentRepaymentMethod.interestFirst,
                rate: const InterestRate(
                  ppm: 48000,
                  period: InterestRatePeriod.annual,
                ),
                accrual: InterestAccrualMethod.daily,
              ),
            ),
          ],
        ),
      );
      for (final (from, reset, effective) in [
        (
          DateTime.utc(2026, 5, 1),
          DateTime.utc(2026, 6, 20),
          DateTime.utc(2026, 6, 21),
        ),
        (
          DateTime.utc(2026, 6, 21),
          DateTime.utc(2026, 12, 20),
          DateTime.utc(2026, 12, 21),
        ),
      ]) {
        await f.service.addConfiguration(
          'annual-scope',
          stageId: 'annual-stage',
          effectiveFrom: from,
          rule: FloatingRateRule(
            referenceRateType: InterestRateType.lprFiveYearPlus,
            spreadBp: -30,
            firstResetDate: reset,
            firstEffectiveDate: effective,
          ),
        );
      }
      f.currentDate = DateTime.utc(2026, 6, 20);
      expect(await f.service.prepare('annual-scope', f.currentDate), isTrue);
      final records = await f.records.list('annual-scope');
      expect(records, hasLength(1));
      expect(records.single.change.resetDate, DateTime.utc(2026, 6, 20));
      expect(records.single.change.effectiveDate, DateTime.utc(2026, 6, 21));
      expect(records.single.change.rate.ppm, 36000);
      var contract = (await f.installments.findContract('annual-scope'))!;
      expect(
        contract.repricingConfigurations.first.lastGeneratedDate,
        DateTime.utc(2026, 6, 20),
      );
      expect(contract.repricingConfigurations.last.lastGeneratedDate, isNull);
      await f.service.runDue(f.currentDate);
      expect((await f.records.list('annual-scope')).single.applied, isTrue);
      expect(
        (await f.installments.listSchedules(
          'annual-scope',
        )).last.expectedInterest.minorUnits,
        292000,
      );
      await f.service.delete('annual-scope', records.single.id);
      await f.service.runDue(f.currentDate);
      expect(await f.records.list('annual-scope'), isEmpty);
      contract = (await f.installments.findContract('annual-scope'))!;
      expect(
        contract.repricingConfigurations.first.lastGeneratedDate,
        DateTime.utc(2026, 6, 20),
      );
    },
  );

  test('balloon final period reprices once and conserves principal', () async {
    await f.seed(
      id: 'balloon',
      borrowingDate: DateTime.utc(2026, 1, 1),
      stageTerms: InstallmentContractTerms(
        stages: [
          InstallmentContractStage(
            id: 'balloon-stage',
            terms: AmortizingStage(
              dates: IntervalRepaymentDates(
                firstDate: DateTime.utc(2026, 2, 1),
                count: 3,
              ),
              method: InstallmentRepaymentMethod.equalInstallment,
              rate: const InterestRate(
                ppm: 48000,
                period: InterestRatePeriod.annual,
              ),
              endPrincipal: const Money(minorUnits: 5000000),
              floatingRate: FloatingRateRule(
                referenceRateType: InterestRateType.lprFiveYearPlus,
                spreadBp: -30,
                firstResetDate: DateTime.utc(2026, 3, 15),
                firstEffectiveDate: DateTime.utc(2026, 3, 15),
              ),
            ),
          ),
        ],
      ),
    );
    f.currentDate = DateTime.utc(2026, 3, 15);
    final before = await f.installments.listSchedules('balloon');
    expect(before.map((r) => r.expectedPrincipal.minorUnits), [
      996011,
      999995,
      6003994,
    ]);
    expect(await f.service.runDue(f.currentDate), (
      changed: true,
      needsRetry: false,
    ));
    final after = await f.installments.listSchedules('balloon');
    expect((await f.records.list('balloon')).single.applied, isTrue);
    expect(after.map((r) => r.expectedPrincipal.minorUnits), [
      996011,
      999995,
      1003994 + 5000000,
    ]);
    // 60039.94 * (4.8% * 14/360 + 3.6% * 17/360) = 214.14.
    expect(after.last.expectedInterest.minorUnits, 21214);
    expect(
      after.take(2).map((r) => r.expectedInterest),
      before.take(2).map((r) => r.expectedInterest),
    );
    expect(
      after.fold<int>(0, (sum, r) => sum + r.expectedPrincipal.minorUnits),
      8000000,
    );
    expect(await f.service.runDue(f.currentDate), (
      changed: false,
      needsRetry: false,
    ));
  });

  for (final prepareOnly in [true, false]) {
    for (final end in [
      DateTime.utc(2027, 2, 20),
      DateTime.utc(2026, 12, 1),
      DateTime.utc(2027, 1, 1),
    ]) {
      test(
        'contract calculation range ignores manually edited plan end $end ($prepareOnly)',
        () async {
          final contract = (await f.installments.findContract('loan'))!;
          final rows = await f.installments.listSchedules('loan');
          rows.last.reviseExpectation(expectedRepaymentDate: end);
          rows.last.manuallyAdjusted = true;
          await f.installments.saveAggregate(contract, rows);
          f.currentDate = DateTime.utc(2026, 12, 20);
          if (prepareOnly) {
            expect(await f.service.prepare('loan', f.currentDate), isTrue);
          } else {
            expect(await f.service.runDue(f.currentDate), (
              changed: true,
              needsRetry: false,
            ));
          }
          final records = await f.records.list('loan');
          expect(records, hasLength(4));
          expect(
            records.every(
              (record) => record.change.effectiveDate.isBefore(
                referenceDate(contract.stageTerms.lastDate),
              ),
            ),
            isTrue,
          );
          final saved = await f.installments.listSchedules('loan');
          expect(
            referenceDate(saved.last.expectedRepaymentDate),
            prepareOnly ? end : referenceDate(contract.stageTerms.lastDate),
          );
        },
      );
    }
  }

  test(
    'repricing automatically replaces manual amounts and requests acknowledgement',
    () async {
      final before = await f.installments.listSchedules('loan');
      before.last.manuallyAdjusted = true;
      before.last.expectedInterest = const Money(minorUnits: 99);
      await f.installments.saveAggregate(
        (await f.installments.findContract('loan'))!,
        before,
      );

      expect(await f.service.runDue(DateTime(2026, 1, 5)), (
        changed: true,
        needsRetry: false,
      ));
      final record = (await f.records.list('loan')).single;
      expect(record.status, InstallmentRepricingStatus.applied);
      final after = await f.installments.listSchedules('loan');
      expect(after.first.expectedInterest.minorUnits, 27733);
      expect(after.last.expectedInterest.minorUnits, isNot(99));
      expect(after.map((r) => r.id), before.map((r) => r.id));
      expect(
        after.map((r) => r.expectedRepaymentDate),
        before.map((r) => r.expectedRepaymentDate),
      );
      final query = InstallmentQueryServiceImpl(
        repository: f.installments,
        repricings: f.records,
      );
      expect((await query.findContract('loan'))!.unconfirmedRepricingIds, [
        record.id,
      ]);
    },
  );

  for (final prepareOnly in [true, false]) {
    test(
      'configuration history owns each effective date via ${prepareOnly ? 'prepare' : 'runDue'}',
      () async {
        AmortizingStage stage(
          DateTime first,
          int count,
          DateTime reset,
          DateTime effective, {
          Money? end,
        }) => AmortizingStage(
          dates: IntervalRepaymentDates(firstDate: first, count: count),
          method: InstallmentRepaymentMethod.equalInstallment,
          rate: const InterestRate(
            ppm: 48000,
            period: InterestRatePeriod.annual,
          ),
          endPrincipal: end,
          floatingRate: FloatingRateRule(
            referenceRateType: InterestRateType.lprFiveYearPlus,
            spreadBp: -30,
            firstResetDate: reset,
            firstEffectiveDate: effective,
            cycleMonths: 3,
          ),
        );
        await f.seed(
          id: 'multi',
          stageTerms: InstallmentContractTerms(
            stages: [
              InstallmentContractStage(
                id: 'first-stage',
                terms: stage(
                  DateTime(2026, 1, 20),
                  6,
                  DateTime(2025, 12, 20),
                  DateTime(2026, 1, 1),
                  end: const Money(minorUnits: 4000000),
                ),
              ),
              InstallmentContractStage(
                id: 'second-stage',
                terms: stage(
                  DateTime(2026, 8, 20),
                  5,
                  DateTime(2026, 6, 20),
                  DateTime(2026, 7, 1),
                ),
              ),
            ],
          ),
        );
        final rows = await f.installments.listSchedules('multi');
        rows[5].reviseExpectation(expectedRepaymentDate: DateTime(2026, 7, 20));
        await f.installments.saveAggregate(
          (await f.installments.findContract('multi'))!,
          rows,
        );
        f.currentDate = DateTime(2026, 12, 20);
        if (prepareOnly) {
          expect(await f.service.prepare('multi', f.currentDate), isTrue);
        } else {
          expect(await f.service.runDue(f.currentDate), (
            changed: true,
            needsRetry: false,
          ));
        }
        final records = await f.records.list('multi');
        expect(
          records
              .where((r) => r.change.effectiveDate.month < 7)
              .map((r) => r.change.effectiveDate.month),
          [1, 4],
        );
        expect(
          records
              .where((r) => r.change.effectiveDate.month >= 7)
              .map((r) => r.change.effectiveDate.month),
          [7, 10],
        );
      },
    );
  }

  for (final end in [DateTime(2026, 9, 20), DateTime(2026, 10, 1)]) {
    test(
      'a manually shortened plan to $end does not hide a contractual repricing',
      () async {
        await f.seed(
          id: 'short',
          stageTerms: InstallmentContractTerms(
            stages: [
              InstallmentContractStage(
                id: 'short-stage',
                terms: AmortizingStage(
                  dates: IntervalRepaymentDates(
                    firstDate: DateTime(2026, 12, 20),
                    count: 1,
                  ),
                  method: InstallmentRepaymentMethod.equalInstallment,
                  rate: const InterestRate(
                    ppm: 48000,
                    period: InterestRatePeriod.annual,
                  ),
                  floatingRate: FloatingRateRule(
                    referenceRateType: InterestRateType.lprFiveYearPlus,
                    spreadBp: -30,
                    firstResetDate: DateTime(2026, 9, 20),
                    firstEffectiveDate: DateTime(2026, 10, 1),
                  ),
                ),
              ),
            ],
          ),
        );
        final rows = await f.installments.listSchedules('short');
        rows.single.reviseExpectation(expectedRepaymentDate: end);
        await f.installments.saveAggregate(
          (await f.installments.findContract('short'))!,
          rows,
        );
        f.currentDate = DateTime(2026, 9, 20);
        expect(await f.service.prepare('short', f.currentDate), isTrue);
        await f.service.runDue(f.currentDate);
        expect(await f.records.list('short'), hasLength(1));
        expect(
          referenceDate(
            (await f.installments.listSchedules(
              'short',
            )).last.expectedRepaymentDate,
          ),
          DateTime.utc(2026, 12, 20),
        );
      },
    );
  }

  for (final missingStageId in [true, false]) {
    test(
      'missing old schedule data does not prevent full calculation ($missingStageId)',
      () async {
        await f.db.customStatement(
          missingStageId
              ? 'UPDATE installment_schedules SET stage_id = NULL'
              : 'DELETE FROM installment_schedules',
        );
        expect(await f.service.prepare('loan', DateTime(2026, 1, 5)), isTrue);
        expect(await f.service.runDue(DateTime(2026, 1, 5)), (
          changed: true,
          needsRetry: false,
        ));
        expect(await f.records.list('loan'), hasLength(1));
        expect(await f.installments.listSchedules('loan'), hasLength(12));
        expect(f.source.calls, isNotEmpty);
      },
    );
  }

  test(
    'one confirmation acknowledges three loaded records and leaves a fourth visible',
    () async {
      f.currentDate = DateTime(2026, 6, 20);
      final task = InstallmentRepricingTask(f.service);
      expect(await task.run(f.currentDate), AppTaskOutcome.completed);
      final query = InstallmentQueryServiceImpl(
        repository: f.installments,
        repricings: f.records,
      );
      final loaded = (await query.findContract(
        'loan',
      ))!.unconfirmedRepricingIds.toSet();
      expect(loaded, hasLength(3));
      expect(await task.run(f.currentDate), AppTaskOutcome.completed);
      f.currentDate = DateTime(2026, 9, 20);
      expect(await task.run(f.currentDate), AppTaskOutcome.completed);
      final before = await DriftBackupGateway(f.db).readSnapshot();
      await f.service.confirm('loan', loaded);
      expect((await f.records.list('loan')).map((r) => r.status), [
        InstallmentRepricingStatus.userConfirmed,
        InstallmentRepricingStatus.userConfirmed,
        InstallmentRepricingStatus.userConfirmed,
        InstallmentRepricingStatus.applied,
      ]);
      final remaining = (await query.findContract(
        'loan',
      ))!.unconfirmedRepricingIds;
      expect(remaining, hasLength(1));
      expect(loaded.contains(remaining.single), isFalse);
      expect(
        (await DriftBackupGateway(
          f.db,
        ).readSnapshot()).rows('installment_schedules'),
        before.rows('installment_schedules'),
      );
      expect(await f.service.runDue(f.currentDate), (
        changed: false,
        needsRetry: false,
      ));
    },
  );

  test('a failure saving the second confirmation rolls back the first', () async {
    f.currentDate = DateTime(2026, 3, 20);
    await f.service.runDue(f.currentDate);
    final records = await f.records.list('loan');
    expect(records, hasLength(2));
    await f.db.customStatement(
      "CREATE TRIGGER reject_second_confirmation AFTER UPDATE ON installment_repricing_records "
      "WHEN NEW.status = 'userConfirmed' AND NEW.id = '${records.last.id}' "
      "BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await expectLater(
      f.service.confirm('loan', records.map((r) => r.id).toSet()),
      throwsA(isA<Exception>()),
    );
    expect(
      (await f.records.list('loan')).map((r) => r.status),
      everyElement(InstallmentRepricingStatus.applied),
    );
    await f.db.customStatement('DROP TRIGGER reject_second_confirmation');
    await f.service.confirm('loan', records.map((r) => r.id).toSet());
    expect(
      (await f.records.list('loan')).map((r) => r.status),
      everyElement(InstallmentRepricingStatus.userConfirmed),
    );
  });

  test(
    'pending record in a confirmation batch rolls back earlier confirmations',
    () async {
      await f.service.runDue(DateTime(2026, 1, 5));
      f.currentDate = DateTime(2026, 3, 20);
      await f.service.prepare('loan', f.currentDate);
      final records = await f.records.list('loan');
      await expectLater(
        f.service.confirm('loan', records.map((r) => r.id).toSet()),
        throwsA(isA<BusinessException>()),
      );
      expect((await f.records.list('loan')).map((r) => r.status), [
        InstallmentRepricingStatus.applied,
        InstallmentRepricingStatus.pending,
      ]);
    },
  );

  test(
    'saving state of a deleted repricing record rejects the missing target',
    () async {
      await f.service.prepare('loan', DateTime(2026, 1, 5));
      final record = (await f.records.list('loan')).single;
      await f.records.delete(record);
      record.markApplied();
      await expectLater(
        f.records.update(record),
        throwsA(isA<BusinessException>()),
      );
      expect(await f.records.list('loan'), isEmpty);
    },
  );

  test(
    'confirmation preserves repaired plans, survives backup and leaves newer results visible',
    () async {
      await f.service.runDue(DateTime(2026, 1, 5));
      final first = (await f.records.list('loan')).single;
      f.currentDate = DateTime(2026, 3, 20);
      await f.service.runDue(f.currentDate);
      final all = await f.records.list('loan');
      expect(all, hasLength(2));
      final rows = await f.installments.listSchedules('loan');
      rows.last.expectedInterest = const Money(minorUnits: 99);
      rows.last.manuallyAdjusted = true;
      await f.installments.saveAggregate(
        (await f.installments.findContract('loan'))!,
        rows,
      );
      final before = await DriftBackupGateway(f.db).readSnapshot();

      await f.service.confirm('loan', {first.id});
      await f.service.confirm('loan', {first.id});
      expect(await f.service.runDue(f.currentDate), (
        changed: false,
        needsRetry: false,
      ));
      final snapshot = await DriftBackupGateway(f.db).readSnapshot();
      expect(
        snapshot.rows('installment_schedules'),
        before.rows('installment_schedules'),
      );
      expect((await f.records.list('loan')).map((r) => r.status), [
        InstallmentRepricingStatus.userConfirmed,
        InstallmentRepricingStatus.applied,
      ]);
      final query = InstallmentQueryServiceImpl(
        repository: f.installments,
        repricings: f.records,
      );
      expect((await query.findContract('loan'))!.unconfirmedRepricingIds, [
        all.last.id,
      ]);
      BackupService.validateSnapshot(snapshot);
      final target = createTestDatabase();
      addTearDown(target.close);
      await DriftBackupGateway(target).replaceSnapshot(snapshot);
      expect(
        (await DriftInstallmentRepricingRepository(
          target,
        ).list('loan')).map((r) => r.status),
        [
          InstallmentRepricingStatus.userConfirmed,
          InstallmentRepricingStatus.applied,
        ],
      );
      expect(
        (await DriftInstallmentRepository(
          target,
        ).findContract('loan'))!.repricings,
        hasLength(2),
      );
      await f.service.confirm('loan', {all.last.id});
      expect(
        (await query.findContract('loan'))!.unconfirmedRepricingIds,
        isEmpty,
      );
    },
  );

  test(
    'confirmation rejects unapplied and foreign records without changing any state',
    () async {
      await f.service.prepare('loan', DateTime(2026, 1, 5));
      final record = (await f.records.list('loan')).single;
      await expectLater(
        f.service.confirm('loan', {record.id}),
        throwsA(isA<BusinessException>()),
      );
      expect(
        (await f.records.list('loan')).single.status,
        InstallmentRepricingStatus.pending,
      );
      await f.service.runDue(DateTime(2026, 1, 5));
      await expectLater(
        f.service.confirm('other', {record.id}),
        throwsA(isA<BusinessException>()),
      );
      await expectLater(
        f.service.confirm('loan', {record.id, 'missing'}),
        throwsA(isA<BusinessException>()),
      );
      expect(
        (await f.records.list('loan')).single.status,
        InstallmentRepricingStatus.applied,
      );
    },
  );

  test('failed confirmation retains the applied result for retry', () async {
    await f.service.runDue(DateTime(2026, 1, 5));
    final record = (await f.records.list('loan')).single;
    await f.db.customStatement(
      "CREATE TRIGGER reject_confirmation AFTER UPDATE ON installment_repricing_records "
      "WHEN NEW.status = 'userConfirmed' BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await expectLater(
      f.service.confirm('loan', {record.id}),
      throwsA(isA<Exception>()),
    );
    expect(
      (await f.records.list('loan')).single.status,
      InstallmentRepricingStatus.applied,
    );
  });

  test(
    'v38 backups migrate application state and invalid new states are rejected',
    () async {
      await f.service.runDue(DateTime(2026, 1, 5));
      f.currentDate = DateTime(2026, 3, 20);
      await f.service.prepare('loan', f.currentDate);
      final snapshot = await DriftBackupGateway(f.db).readSnapshot();
      final tables = <String, Iterable<BackupJson>>{
        ...legacyInstallmentSnapshot(snapshot, stageRepricing: true),
        'installment_repricing_records': [
          for (final row in snapshot.rows('installment_repricing_records'))
            {...row, 'applied': row['status'] == 'applied'}..remove('status'),
        ],
      };
      migrateInstallmentBackup(tables, schemaVersion: 38, formatVersion: 3);
      final migrated = snapshot.copyWith(tables: tables);
      BackupService.validateSnapshot(migrated);
      expect(BackupDiff.compare(snapshot, migrated).changedCount, 0);
      final target = createTestDatabase();
      addTearDown(target.close);
      await DriftBackupGateway(target).replaceSnapshot(migrated);
      expect(
        (await DriftInstallmentRepricingRepository(
          target,
        ).list('loan')).map((r) => r.status),
        [
          InstallmentRepricingStatus.applied,
          InstallmentRepricingStatus.pending,
        ],
      );
      final invalid = snapshot.copyWith(
        tables: {
          ...snapshot.tables,
          'installment_repricing_records': [
            for (final row in snapshot.rows('installment_repricing_records'))
              {...row, 'status': 'unknown'},
          ],
        },
      );
      expect(
        () => BackupService.validateSnapshot(invalid),
        throwsA(isA<BackupValidationException>()),
      );
    },
  );

  for (final now in [DateTime(2025, 12, 20), DateTime(2026, 1, 5)]) {
    test('repricing at $now excludes the reset day quote', () async {
      f.currentDate = now;
      f.source.rates.add(
        ReferenceRate(
          type: InterestRateType.lprFiveYearPlus,
          date: DateTime.utc(2025, 12, 20),
          ratePpm: 30000,
          source: f.source.key,
        ),
      );
      await f.service.prepare('loan', now);
      final change = (await f.records.list('loan')).single.change;
      expect(referenceDate(change.resetDate), DateTime.utc(2025, 12, 20));
      expect(
        referenceDate(change.referenceRate.date),
        DateTime.utc(2025, 12, 19),
      );
      expect(change.rate.ppm, 36000);
      // General loan rate lookup still includes a published quote on the day.
      final inclusive = await f.referenceRates.resolveOne(
        InterestRateType.lprFiveYearPlus,
        DateTime(2025, 12, 20),
      );
      expect(inclusive.rate?.ratePpm, 30000);
    });
  }

  test(
    'a quote only on the reset day cannot create a repricing fact',
    () async {
      f.source.rates
        ..clear()
        ..add(
          ReferenceRate(
            type: InterestRateType.lprFiveYearPlus,
            date: DateTime.utc(2025, 12, 20),
            ratePpm: 30000,
            source: f.source.key,
          ),
        );
      expect(await f.service.runDue(DateTime(2025, 12, 20)), (
        changed: false,
        needsRetry: true,
      ));
      expect(await f.records.list('loan'), isEmpty);
    },
  );

  test(
    'missing later quotes do not block automatic application of the earliest candidate',
    () async {
      await f.service.prepare('loan', DateTime(2026, 1, 5));
      f.currentDate = DateTime(2026, 3, 20);
      f.source.omitted.add(InterestRateType.lprFiveYearPlus);
      expect(await f.service.runDue(f.currentDate), (
        changed: true,
        needsRetry: true,
      ));
      expect((await f.records.list('loan')).single.applied, isTrue);
    },
  );

  test(
    'one failed contract requests retry without blocking healthy contracts',
    () async {
      await f.seed(id: 'other');
      await f.db.customStatement(
        "CREATE TRIGGER reject_repricing BEFORE UPDATE ON installment_repricing_records "
        "WHEN NEW.contract_id = 'loan' BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      final before = await f.installments.listSchedules('loan');
      expect(await f.service.runDue(DateTime(2026, 1, 5)), (
        changed: true,
        needsRetry: true,
      ));
      expect((await f.records.list('loan')).single.applied, isFalse);
      expect((await f.records.list('other')).single.applied, isTrue);
      expect(
        (await f.installments.listSchedules('loan')).first.expectedInterest,
        before.first.expectedInterest,
      );
      await f.db.customStatement('DROP TRIGGER reject_repricing');
      expect(await f.service.runDue(DateTime(2026, 1, 5)), (
        changed: true,
        needsRetry: false,
      ));
      expect((await f.records.list('loan')).single.applied, isTrue);
    },
  );

  test(
    'terms preview changes the initial rate and still consumes applied repricing facts',
    () async {
      await f.service.runDue(DateTime(2026, 1, 5));
      final contract = (await f.installments.findContract('loan'))!;
      final original = contract.stageTerms.stages.single;
      final old = original.terms as AmortizingStage;
      final replacement = InstallmentContractTerms(
        stages: [
          InstallmentContractStage(
            id: original.id,
            terms: AmortizingStage(
              dates: old.dates,
              method: old.method,
              accrual: old.accrual,
              rate: const InterestRate(
                period: InterestRatePeriod.annual,
                ppm: 60000,
              ),
              floatingRate: old.floatingRate,
              endPrincipal: old.endPrincipal,
              fee: old.fee,
              installmentAmount: old.installmentAmount,
            ),
          ),
        ],
      );
      final before = await f.installments.listSchedules('loan');
      final facts = await f.records.list('loan');
      final preview = await f.plans.previewChange(
        'loan',
        RecalculateFromTerms(replacement),
      );
      await f.plans.confirmChange(
        'loan',
        RecalculateFromTerms(replacement),
        token: preview.token,
      );
      expect(
        (await f.installments.findContract(
          'loan',
        ))!.stageTerms.repayments.single.rate,
        replacement.repayments.single.rate,
      );
      expect(
        (await f.records.list('loan')).single.change.rate,
        facts.single.change.rate,
      );
      expect(
        (await f.installments.listSchedules('loan')).first.expectedInterest,
        isNot(before.first.expectedInterest),
      );
    },
  );

  test(
    'repricing rebuilds fees from terms and clears manual adjustments',
    () async {
      final contract = (await f.installments.findContract('loan'))!;
      final rows = await f.installments.listSchedules('loan');
      rows.first.reviseExpectation(expectedFee: const Money(minorUnits: 99));
      rows.last.reviseExpectation(expectedFee: const Money(minorUnits: 3));
      rows.first.manuallyAdjusted = true;
      await f.installments.saveAggregate(contract, rows);
      await f.service.runDue(DateTime(2026, 1, 5));
      expect(
        (await f.installments.listSchedules('loan')).map((r) => r.expectedFee),
        everyElement(Money.zero()),
      );
      expect(
        (await f.installments.listSchedules(
          'loan',
        )).every((row) => !row.manuallyAdjusted),
        isTrue,
      );
    },
  );

  for (final prepayFirst in [true, false]) {
    test(
      '200000 loan: ${prepayFirst ? '12/13 prepayment then repricing' : 'repricing then 1/5 prepayment'} preserves exact installments',
      () async {
        await f.seedRepaymentExample();
        final before = await f.installments.listSchedules('example');
        // 月计息，初始 4.8%，固定额 17103.17 元；1/2 起 3.6%。
        expect(before.take(3).map((r) => r.expectedPrincipal.minorUnits), [
          1630317,
          1636838,
          1643386,
        ]);
        expect(before[3].expectedPrincipal.minorUnits, 1649959);

        if (prepayFirst) {
          await f.prepayExample(DateTime.utc(2024, 12, 13));
          final prepaid = await f.installments.listSchedules('example');
          expect(prepaid[3].expectedPrincipal.minorUnits, 1540614);
          expect(prepaid[3].expectedInterest.minorUnits, 56358);
        }
        // 取值日已确定的结果可提前应用，1/2 仍是实际拆息日期。
        await f.service.runDue(DateTime.utc(2025, 1, 1));
        expect(
          (await f.installments.listSchedules(
            'example',
          ))[3].expectedPrincipal.minorUnits,
          prepayFirst ? 1540614 : 1649959,
        );
        expect((await f.records.list('example')).single.applied, isTrue);
        if (!prepayFirst) {
          await f.prepayExample(DateTime.utc(2025, 1, 5));
        }

        final after = await f.installments.listSchedules('example');
        expect(after.map((r) => r.id), before.map((r) => r.id));
        expect(after.map((r) => r.stageId), before.map((r) => r.stageId));
        expect(
          after.map((r) => referenceDate(r.expectedRepaymentDate)),
          before.map((r) => referenceDate(r.expectedRepaymentDate)),
        );
        for (var i = 0; i < 3; i++) {
          expect(after[i].status, InstallmentScheduleStatus.paid);
          expect(after[i].expectedPrincipal, before[i].expectedPrincipal);
          expect(after[i].expectedInterest, before[i].expectedInterest);
          expect(after[i].expectedFee, before[i].expectedFee);
        }
        // P=140894.59；A0=15969.72；本金4=A0-round(P*4.8%/12)。
        // 利息4=round(P*(4.8%*20/360+3.6%*11/360))=530.70。
        // 第5期起固定额15898.56，末期吸收尾差。这些期望值按月供公式独立推导。
        expect(
          after
              .skip(3)
              .map(
                (r) => (
                  r.expectedPrincipal.minorUnits,
                  r.expectedInterest.minorUnits,
                ),
              ),
          [
            (1540614, 53070),
            (1552209, 37647),
            (1556866, 32990),
            (1561537, 28319),
            (1566221, 23635),
            (1570920, 18936),
            (1575633, 14223),
            (1580360, 9496),
            (1585099, 4755),
          ],
        );
        expect(
          after
              .skip(3)
              .every((r) => r.status == InstallmentScheduleStatus.pending),
          isTrue,
        );
        expect(
          after.fold<int>(0, (sum, r) => sum + r.expectedPrincipal.minorUnits),
          19000000,
        );
      },
    );
  }

  test(
    'repricing replaces manual transition principal with the current projection',
    () async {
      final contract = (await f.installments.findContract('loan'))!;
      final rows = await f.installments.listSchedules('loan');
      // 手工调整本金并在末期补回，保证计划本金守恒。
      final projectedPrincipal = rows.first.expectedPrincipal.minorUnits;
      rows.last.expectedPrincipal +=
          rows.first.expectedPrincipal - const Money(minorUnits: 600000);
      rows.first.expectedPrincipal = const Money(minorUnits: 600000);
      rows.first.manuallyAdjusted = true;
      await f.installments.saveAggregate(contract, rows);
      await f.service.runDue(DateTime(2026, 1, 5));
      expect(
        (await f.installments.listSchedules(
          'loan',
        )).first.expectedInterest.minorUnits,
        27733,
      );
      expect(
        (await f.installments.listSchedules(
          'loan',
        )).first.expectedPrincipal.minorUnits,
        projectedPrincipal,
      );
    },
  );

  test(
    'due loans with different rate types share one source request',
    () async {
      await f.seed(id: 'other', type: InterestRateType.lprOneYear);
      final result = await f.service.runDue(DateTime(2026, 1, 5));
      expect(result, (changed: true, needsRetry: false));
      expect(
        f.source.calls.single,
        unorderedEquals([
          InterestRateType.lprOneYear,
          InterestRateType.lprFiveYearPlus,
        ]),
      );
      expect((await f.records.list('loan')).single.applied, isTrue);
      expect((await f.records.list('other')).single.applied, isTrue);
    },
  );

  test(
    'a failed type leaves only its loan waiting and can retry the same day',
    () async {
      await f.seed(id: 'other', type: InterestRateType.lprOneYear);
      f.source.omitted.add(InterestRateType.lprOneYear);
      expect(await f.service.runDue(DateTime(2026, 1, 5)), (
        changed: true,
        needsRetry: true,
      ));
      expect((await f.records.list('loan')).single.applied, isTrue);
      expect(await f.records.list('other'), isEmpty);
      f.source.omitted.clear();
      expect(await f.service.runDue(DateTime(2026, 1, 5)), (
        changed: true,
        needsRetry: false,
      ));
      expect(f.source.calls.last, [InterestRateType.lprOneYear]);
      expect((await f.records.list('other')).single.applied, isTrue);
    },
  );

  for (final type in InterestRateType.referenceTypes) {
    test(
      '${type.name} survives repricing, persistence and backup replacement',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.db.close);
        await fixture.seed(type: type);
        final outcome = await fixture.service.runDue(DateTime(2026, 1, 5));
        expect(outcome, (changed: true, needsRetry: false));
        final snapshot = await DriftBackupGateway(fixture.db).readSnapshot();
        BackupService.validateSnapshot(snapshot);
        final target = createTestDatabase();
        addTearDown(target.close);
        await DriftBackupGateway(target).replaceSnapshot(snapshot);
        final restored = (await DriftInstallmentRepository(
          target,
        ).findContract('loan'))!;
        expect(
          restored.repricingConfigurations.single.rule.referenceRateType,
          type,
        );
        expect(restored.repricings.single.change.referenceRate.type, type);
        expect(restored.repricings.single.change.referenceRate.ratePpm, 39000);
        expect(restored.repricings.single.change.rate.ppm, 36000);
        expect(
          (await target.select(target.referenceRates).getSingle()).type,
          type.name,
        );
        expect(
          (await target.select(target.installmentRepricingRecords).getSingle())
              .status,
          'applied',
        );
      },
    );
  }

  test(
    'schema 37 backup migrates floating terms and snapshots before validation and restore',
    () async {
      await f.service.runDue(DateTime(2026, 1, 5));
      final snapshot = await DriftBackupGateway(f.db).readSnapshot();
      final tables = legacyInstallmentSnapshot(snapshot, stageRepricing: true);
      final configuration = snapshot
          .rows('installment_repricing_configs')
          .single;
      tables.remove('installment_repricing_configs');
      tables.remove('installment_interest_adjustments');
      tables['installment_stage_configs'] = [
        for (final row in tables['installment_stage_configs']!)
          if (row['ownerType'] != 'contract' || row['stageKind'] != 'repayment')
            row
          else
            {
              ...row,
              'lprTenor': 'fiveYearPlus',
              'spreadBp': configuration['spreadBp'],
              'firstResetDate': configuration['firstResetDate'],
              'firstEffectiveDate': configuration['firstEffectiveDate'],
              'repricingCycleMonths': configuration['cycleMonths'],
            }..remove('referenceRateType'),
      ];
      tables['installment_repricing_records'] = [
        for (final row in snapshot.rows('installment_repricing_records'))
          {
              ...row,
              'stageId': 'stage',
              'applied': true,
              'tenor': 'fiveYearPlus',
              'quoteDate': row['referenceRateDate'],
              'lprPpm': row['referenceRatePpm'],
            }
            ..remove('status')
            ..remove('referenceRateType')
            ..remove('referenceRateDate')
            ..remove('referenceRatePpm'),
      ];
      migrateInstallmentBackup(tables, schemaVersion: 37, formatVersion: 3);
      final migrated = snapshot.copyWith(tables: tables);
      BackupService.validateSnapshot(migrated);
      expect(BackupDiff.compare(snapshot, migrated).changedCount, 0);
      final target = createTestDatabase();
      addTearDown(target.close);
      await DriftBackupGateway(target).replaceSnapshot(migrated);
      final restored = (await DriftInstallmentRepository(
        target,
      ).findContract('loan'))!;
      expect(
        restored.repricingConfigurations.single.rule.referenceRateType,
        InterestRateType.lprFiveYearPlus,
      );
      expect(
        restored.repricingConfigurations.single.lastGeneratedDate,
        DateTime.utc(2025, 12, 20),
      );
      expect(restored.repricings.single.change.rate.ppm, 36000);
      expect(
        (await target.select(target.installmentRepricingRecords).getSingle())
            .status,
        'applied',
      );
    },
  );

  test(
    'saving a repricing snapshot does not write shared reference rates',
    () async {
      await f.service.prepare('loan', DateTime(2026, 1, 5));
      final record = (await f.records.list('loan')).single;
      await f.db.customStatement(
        "CREATE TRIGGER reject_reference_rate_write BEFORE INSERT ON reference_rates "
        "BEGIN SELECT RAISE(ABORT, 'unexpected shared rate write'); END",
      );
      await f.records.insert(record);
      expect(await f.records.list('loan'), hasLength(1));
    },
  );

  test(
    'issued bill allows automatic repricing and retains its projected amounts',
    () async {
      final before = (await f.installments.listSchedules('loan')).first;
      await f.db.customStatement(
        "INSERT INTO bills (id, account_id, period, status) VALUES ('bill', 'account', 202601, 'billed')",
      );
      await f.db.customStatement(
        "INSERT INTO bill_items (id, bill_id, item_type, billing_state, contract_id, schedule_id, "
        "repayment_date, expected_principal_minor, expected_interest_minor, expected_fee_minor, status) "
        "VALUES ('item', 'bill', 'installment', 'billed', 'loan', 'period-1', ?, ?, ?, 0, 'pending')",
        [
          before.expectedRepaymentDate.millisecondsSinceEpoch ~/ 1000,
          before.expectedPrincipal.minorUnits,
          before.expectedInterest.minorUnits,
        ],
      );
      await f.service.runDue(DateTime(2026, 1, 5));
      expect((await f.records.list('loan')).single.applied, isTrue);
      final item = await f.db.select(f.db.billItems).getSingle();
      expect(item.expectedPrincipalMinor, before.expectedPrincipal.minorUnits);
      expect(item.expectedInterestMinor, before.expectedInterest.minorUnits);
      expect(
        (await f.installments.listSchedules(
          'loan',
        )).first.expectedInterest.minorUnits,
        27733,
      );
    },
  );

  test(
    'stores and applies snapshots idempotently while preserving schedule identities',
    () async {
      final before = await f.installments.listSchedules('loan');
      expect(await f.service.runDue(DateTime(2026, 1, 5)), (
        changed: true,
        needsRetry: false,
      ));
      expect(await f.records.list('loan'), hasLength(1));
      expect(await f.db.select(f.db.referenceRates).get(), hasLength(1));
      final after = await f.installments.listSchedules('loan');
      expect(after.first.expectedPrincipal, before.first.expectedPrincipal);
      expect(after.map((r) => r.id), before.map((r) => r.id));
      expect(after.map((r) => r.stageId), before.map((r) => r.stageId));
      expect(
        after.map((r) => r.expectedRepaymentDate),
        before.map((r) => r.expectedRepaymentDate),
      );
      expect(after.first.expectedInterest.minorUnits, 27733);
      expect(
        (await f.installments.findContract('loan'))!.repricings,
        hasLength(1),
      );
      expect(await f.service.runDue(DateTime(2026, 1, 6)), (
        changed: false,
        needsRetry: false,
      ));
      expect(await f.records.list('loan'), hasLength(1));
    },
  );

  test(
    'automatic repricing rebuilds all amounts and repairs stale status from repayment facts',
    () async {
      final rows = await f.installments.listSchedules('loan');
      rows.last.manuallyAdjusted = true;
      rows.last.expectedInterest = const Money(minorUnits: 99);
      await f.installments.saveAggregate(
        (await f.installments.findContract('loan'))!,
        rows,
      );
      await f.service.prepare('loan', DateTime(2026, 1, 5));
      expect((await f.records.list('loan')).single.applied, isFalse);
      final changed = await f.installments.listSchedules('loan');
      changed.first.expectedInterest = const Money(minorUnits: 500);
      changed.first.markPaid();
      await f.installments.saveAggregate(
        (await f.installments.findContract('loan'))!,
        changed,
      );
      expect(await f.service.runDue(DateTime(2026, 1, 5)), (
        changed: true,
        needsRetry: false,
      ));
      expect((await f.records.list('loan')).single.applied, isTrue);
      final saved = await f.installments.listSchedules('loan');
      expect(saved.first.status, InstallmentScheduleStatus.pending);
      expect(saved.first.expectedInterest.minorUnits, 27733);
      expect(saved.last.expectedInterest.minorUnits, isNot(99));
    },
  );

  test(
    'late repricing recalculates paid periods while preserving actual repayment references',
    () async {
      final rows = await f.installments.listSchedules('loan');
      await f.pay(rows.first, 'loan');
      rows.first.markPaid();
      await f.installments.saveAggregate(
        (await f.installments.findContract('loan'))!,
        rows,
      );
      await f.service.runDue(DateTime(2026, 2, 1));
      expect((await f.records.list('loan')).single.applied, isTrue);
      final saved = await f.installments.listSchedules('loan');
      expect(saved.first.status, InstallmentScheduleStatus.paid);
      expect(saved.first.expectedPrincipal, rows.first.expectedPrincipal);
      expect(saved.first.expectedInterest.minorUnits, 27733);
      expect(saved.last.expectedInterest, isNot(rows.last.expectedInterest));
    },
  );

  test(
    'unavailable reference rates leave plans and referenceRate history untouched',
    () async {
      final before = await DriftBackupGateway(f.db).readSnapshot();
      f.source.rates.clear();
      final outcome = await f.service.runDue(DateTime(2026, 1, 5));
      expect(outcome.needsRetry, isTrue);
      expect(outcome.changed, isFalse);
      expect(await f.records.list('loan'), isEmpty);
      expect(await f.db.select(f.db.referenceRates).get(), isEmpty);
      final after = await DriftBackupGateway(f.db).readSnapshot();
      expect(
        after.rows('installment_schedules'),
        before.rows('installment_schedules'),
      );
    },
  );

  test(
    'repricing task retries missing quotes and completes once rates become available',
    () async {
      final saved = f.source.rates.toList();
      f.source.rates.clear();
      final task = InstallmentRepricingTask(f.service);
      expect(await task.run(DateTime(2026, 1, 5)), AppTaskOutcome.retryLater);
      f.source.rates.addAll(saved);
      expect(await task.run(DateTime(2026, 1, 5)), AppTaskOutcome.completed);
      expect((await f.records.list('loan')).single.applied, isTrue);
    },
  );

  test('concurrent task executions apply each reset once', () async {
    final outcomes = await Future.wait([
      f.service.runDue(DateTime(2026, 1, 5)),
      f.service.runDue(DateTime(2026, 1, 5)),
    ]);
    expect(outcomes.where((result) => result.changed), hasLength(1));
    expect(outcomes.every((result) => !result.needsRetry), isTrue);
    expect((await f.records.list('loan')).single.applied, isTrue);
    final rows = await f.installments.listSchedules('loan');
    expect(rows.first.expectedInterest.minorUnits, 27733);
    expect(
      rows.fold<int>(0, (sum, r) => sum + r.expectedPrincipal.minorUnits),
      8000000,
    );
  });

  test(
    'failure after saving plan rolls back both plan and application status',
    () async {
      await f.service.prepare('loan', DateTime(2026, 1, 5));
      final before = await f.installments.listSchedules('loan');
      await f.db.customStatement(
        "CREATE TRIGGER reject_repricing BEFORE UPDATE ON installment_repricing_records BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      expect(await f.service.runDue(DateTime(2026, 1, 5)), (
        changed: false,
        needsRetry: true,
      ));
      expect(
        (await f.installments.listSchedules('loan')).first.expectedInterest,
        before.first.expectedInterest,
      );
      expect((await f.records.list('loan')).single.applied, isFalse);
    },
  );

  test(
    'prepayment resets whole-period opening principal to 80000 after repricing',
    () async {
      await f.service.runDue(DateTime(2026, 1, 5));
      final contract = (await f.installments.findContract('loan'))!;
      // From an 80000 contract, reducing principal by 20000 means both rate segments use 60000.
      final updates = const InstallmentPlanEngine()
          .generate(
            contract.stageTerms.planTerms(
              contract.principal,
              contract.borrowingDate,
            ),
            operations: InstallmentPlanOperations(
              principalReductions: [
                PrincipalReduction(
                  date: DateTime(2026, 1, 10),
                  principal: const Money(minorUnits: 2000000),
                ),
              ],
              rateChangesByStage: {
                0: [for (final record in contract.repricings) record.change],
              },
            ),
          )
          .entries;
      expect(updates.first.expectedInterest.minorUnits, 20800);
      expect(
        updates.fold<int>(0, (sum, r) => sum + r.expectedPrincipal.minorUnits),
        6000000,
      );
    },
  );

  test(
    'deleting contract removes repricing results but retains shared quotes',
    () async {
      await f.service.prepare('loan', DateTime(2026, 1, 5));
      await f.installments.deleteContract('loan');
      expect(await f.records.list('loan'), isEmpty);
      expect(await f.db.select(f.db.referenceRates).get(), hasLength(1));
    },
  );

  test(
    'logical backup round trip retains floating terms and applied rate history',
    () async {
      await f.service.runDue(DateTime(2026, 1, 5));
      final gateway = DriftBackupGateway(f.db);
      final snapshot = await gateway.readSnapshot();
      BackupService.validateSnapshot(snapshot);
      expect(BackupDiff.compare(snapshot, snapshot).changedCount, 0);
      await gateway.replaceSnapshot(snapshot);
      final restored = (await f.installments.findContract('loan'))!;
      expect(restored.repricingConfigurations.single.rule.spreadBp, -30);
      expect(restored.repricings.single.change.rate.ppm, 36000);
      expect(
        (await f.installments.listSchedules(
          'loan',
        )).first.expectedInterest.minorUnits,
        27733,
      );
      expect((await f.records.list('loan')).single.applied, isTrue);
    },
  );
}

class _Source implements ReferenceRateSource {
  final calls = <List<InterestRateType>>[];
  final omitted = <InterestRateType>{};
  @override
  String get key => 'fixture';
  @override
  int get order => 100;
  @override
  Set<InterestRateType> get supportedTypes =>
      InterestRateType.referenceTypes.toSet();

  final rates = [
    ReferenceRate(
      type: InterestRateType.lprFiveYearPlus,
      date: DateTime.utc(2025, 12, 19),
      ratePpm: 39000,
      source: 'fixture',
    ),
  ];

  @override
  Future<Map<InterestRateType, List<ReferenceRate>>> fetch(
    List<InterestRateType> types, {
    required DateTime from,
    required DateTime through,
  }) async {
    calls.add(types);
    return {
      for (final type in types)
        if (!omitted.contains(type))
          type: rates
              .where(
                (rate) =>
                    rate.type == type &&
                    !rate.date.isBefore(from) &&
                    !rate.date.isAfter(through),
              )
              .toList(),
    };
  }
}

class _Fixture {
  final AppDatabase db = createTestDatabase();
  DateTime currentDate = DateTime(2026, 2, 20);
  late final installments = DriftInstallmentRepository(db);
  late final records = DriftInstallmentRepricingRepository(db);
  final source = _Source();
  late final referenceRates = ReferenceRateService(
    repository: DriftReferenceRateRepository(db),
    sources: [source],
    runner: DriftTransactionRunner(db),
    clock: () => currentDate,
  );
  late final service = InstallmentRepricingService(
    installments: installments,
    records: records,
    referenceRates: referenceRates,
    plans: plans,
    runner: DriftTransactionRunner(db),
  );
  late final plans = InstallmentPlanService(
    installments: installments,
    repayments: DriftRepaymentRepository(db),
    bills: DriftBillRepository(db),
    runner: DriftTransactionRunner(db),
    idGenerator: _PlanIds(),
  );
  Future<void> seed({
    String id = 'loan',
    InterestRateType type = InterestRateType.lprFiveYearPlus,
    InstallmentContractTerms? stageTerms,
    Money principal = const Money(minorUnits: 8000000),
    DateTime? borrowingDate,
  }) async {
    final stageId = id == 'loan' ? 'stage' : '$id-stage';
    source.rates
      ..removeWhere((rate) => rate.type == type)
      ..add(
        ReferenceRate(
          type: type,
          date: DateTime.utc(2025, 12, 19),
          ratePpm: 39000,
          source: source.key,
        ),
      );
    await db.customStatement(
      "INSERT OR IGNORE INTO accounts (id, name, account_type, account_subtype, account_profile_key) "
      "VALUES ('account', '测试贷款', 'liability', 'loan', 'credit.loan')",
    );
    final terms =
        stageTerms ??
        InstallmentContractTerms(
          stages: [
            InstallmentContractStage(
              id: stageId,
              terms: AmortizingStage(
                dates: IntervalRepaymentDates(
                  firstDate: DateTime(2026, 1, 20),
                  count: 12,
                ),
                method: InstallmentRepaymentMethod.equalInstallment,
                rate: const InterestRate(
                  ppm: 48000,
                  period: InterestRatePeriod.annual,
                ),
                floatingRate: FloatingRateRule(
                  referenceRateType: type,
                  spreadBp: -30,
                  firstResetDate: DateTime(2025, 12, 20),
                  firstEffectiveDate: DateTime(2026, 1, 1),
                  cycleMonths: 3,
                ),
              ),
            ),
          ],
        );
    var period = 0;
    final aggregate = const InstallmentOriginationService()
        .originateDisbursement(
          contractId: id,
          liabilityAccountId: 'account',
          createdAt: borrowingDate ?? DateTime(2025, 12, 20),
          terms: InstallmentOriginationTerms(
            principal: principal,
            borrowingDate: borrowingDate ?? DateTime(2025, 12, 20),
            stageTerms: terms,
          ),
          newScheduleId: () =>
              id == 'loan' ? 'period-${++period}' : '$id-period-${++period}',
        );
    await installments.insertAggregate(aggregate.contract, aggregate.schedules);
    var start = aggregate.contract.borrowingDate;
    for (final configuration in terms.stages) {
      switch (configuration.terms) {
        case DefermentStage(:final until):
          start = until;
        case final AmortizingStage stage:
          if (stage.floatingRate case final rule?) {
            await service.addConfiguration(
              id,
              stageId: configuration.id,
              effectiveFrom: stage.accrualStartDate ?? start,
              rule: rule,
            );
          }
          start = stage.dates.getDates().last;
      }
    }
  }

  Future<void> seedRepaymentExample() async {
    await seed(
      id: 'example',
      principal: const Money(minorUnits: 20000000),
      borrowingDate: DateTime.utc(2024, 9, 8),
      stageTerms: InstallmentContractTerms(
        stages: [
          InstallmentContractStage(
            id: 'example-stage',
            terms: AmortizingStage(
              dates: IntervalRepaymentDates(
                firstDate: DateTime.utc(2024, 10, 12),
                count: 12,
              ),
              method: InstallmentRepaymentMethod.equalInstallment,
              rate: const InterestRate(
                ppm: 48000,
                period: InterestRatePeriod.annual,
              ),
              floatingRate: FloatingRateRule(
                referenceRateType: InterestRateType.lprFiveYearPlus,
                spreadBp: -30,
                firstResetDate: DateTime.utc(2025, 1, 1),
                firstEffectiveDate: DateTime.utc(2025, 1, 2),
                cycleMonths: 6,
              ),
            ),
          ),
        ],
      ),
    );
    source.rates.add(
      ReferenceRate(
        type: InterestRateType.lprFiveYearPlus,
        date: DateTime.utc(2024, 12, 20),
        ratePpm: 39000,
        source: source.key,
      ),
    );
    final rows = await installments.listSchedules('example');
    for (final row in rows.take(3)) {
      await pay(row, 'example');
      row.markPaid();
    }
    await installments.saveAggregate(
      (await installments.findContract('example'))!,
      rows,
    );
  }

  Future<void> pay(InstallmentSchedule row, String contractId) async {
    final billId = 'bill-${row.id}', itemId = 'item-${row.id}';
    await db.customStatement(
      'INSERT INTO bills (id, account_id, period, status) VALUES (?, ?, ?, ?)',
      [
        billId,
        'account',
        row.expectedRepaymentDate.year * 100 + row.expectedRepaymentDate.month,
        'billed',
      ],
    );
    await db.customStatement(
      'INSERT INTO bill_items (id, bill_id, item_type, billing_state, contract_id, schedule_id, '
      'repayment_date, expected_principal_minor, expected_interest_minor, expected_fee_minor, status) '
      "VALUES (?, ?, 'installment', 'billed', ?, ?, ?, ?, ?, ?, 'paid')",
      [
        itemId,
        billId,
        contractId,
        row.id,
        row.expectedRepaymentDate.millisecondsSinceEpoch ~/ 1000,
        row.expectedPrincipal.minorUnits,
        row.expectedInterest.minorUnits,
        row.expectedFee.minorUnits,
      ],
    );
    await DriftRepaymentRepository(db).saveRepayment(
      Repayment(
        id: 'paid-${row.id}',
        repaymentType: RepaymentType.bill,
        targetType: RepaymentTargetType.bill,
        targetId: billId,
        repaymentDate: row.expectedRepaymentDate,
        items: [
          RepaymentItem(
            id: 'allocation-${row.id}',
            repaymentId: 'paid-${row.id}',
            billItemId: itemId,
            allocated: RepaymentAmountBreakdown(
              principal: row.expectedPrincipal,
              interest: row.expectedInterest,
              fee: row.expectedFee,
              discount: Money.zero(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> prepayExample(DateTime date) async {
    final repayments = DriftRepaymentRepository(db);
    await DriftTransactionRunner(db).run(() async {
      await repayments.saveRepayment(
        Repayment(
          id: 'prepayment',
          repaymentType: RepaymentType.prepayment,
          targetType: RepaymentTargetType.contract,
          targetId: 'example',
          repaymentDate: date,
          items: [
            RepaymentItem(
              id: 'prepayment-item',
              repaymentId: 'prepayment',
              allocated: const RepaymentAmountBreakdown(
                principal: Money(minorUnits: 1000000),
                interest: Money(minorUnits: 0),
                fee: Money(minorUnits: 0),
                discount: Money(minorUnits: 0),
              ),
            ),
          ],
        ),
      );
      await plans.applyAutomaticChange(
        'example',
        const RecalculateFromOperations(),
      );
    });
  }
}

class _PlanIds implements IdGenerator {
  int next = 0;
  @override
  String newId() => 'plan-${next++}';
}
