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
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
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
      expect(after.first.expectedInterest.minorUnits, 28000);
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
        ).findContract('loan'))!.stageTerms.repayments.single.rateChanges,
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
        ...snapshot.tables,
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
          type: ReferenceRateType.lprFiveYearPlus,
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
        ReferenceRateType.lprFiveYearPlus,
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
            type: ReferenceRateType.lprFiveYearPlus,
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
      f.source.omitted.add(ReferenceRateType.lprFiveYearPlus);
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
    'terms preview cannot rewrite the rate behind applied repricing facts',
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
              rateChanges: old.rateChanges,
              endPrincipal: old.endPrincipal,
              fee: old.fee,
              installmentAmount: old.installmentAmount,
            ),
          ),
        ],
      );
      await expectLater(
        f.plans.previewChange('loan', RecalculateFromTerms(replacement)),
        throwsA(isA<BusinessException>()),
      );
      expect(
        (await f.installments.findContract(
          'loan',
        ))!.stageTerms.repayments.single.rate,
        old.rate,
      );
    },
  );

  test('repricing retains manually allocated fees on every period', () async {
    final contract = (await f.installments.findContract('loan'))!;
    final rows = await f.installments.listSchedules('loan');
    rows.first.reviseExpectation(expectedFee: const Money(minorUnits: 99));
    rows.last.reviseExpectation(expectedFee: const Money(minorUnits: 3));
    rows.first.manuallyAdjusted = true;
    await f.installments.saveAggregate(contract, rows);
    await f.service.runDue(DateTime(2026, 1, 5));
    expect(
      (await f.installments.listSchedules('loan')).map((r) => r.expectedFee),
      rows.map((r) => r.expectedFee),
    );
  });

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
          after.map((r) => r.expectedRepaymentDate),
          before.map((r) => r.expectedRepaymentDate),
        );
        for (var i = 0; i < 3; i++) {
          expect(after[i].status, InstallmentScheduleStatus.paid);
          expect(after[i].expectedPrincipal, before[i].expectedPrincipal);
          expect(after[i].expectedInterest, before[i].expectedInterest);
          expect(after[i].expectedFee, before[i].expectedFee);
        }
        // P=140894.59；A0=15969.72；本金4=A0-round(P*4.8%/12)。
        // 利息4=round(P*(4.8%*21/360+3.6%*10/360))=535.40。
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
            (1540614, 53540),
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
    'repricing uses the saved transition principal even when it differs from projection',
    () async {
      final contract = (await f.installments.findContract('loan'))!;
      final rows = await f.installments.listSchedules('loan');
      // 手工调整本金并在末期补回，保证计划本金守恒。
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
        28000,
      );
      expect(
        (await f.installments.listSchedules(
          'loan',
        )).first.expectedPrincipal.minorUnits,
        600000,
      );
    },
  );

  test(
    'due loans with different rate types share one source request',
    () async {
      await f.seed(id: 'other', type: ReferenceRateType.lprOneYear);
      final result = await f.service.runDue(DateTime(2026, 1, 5));
      expect(result, (changed: true, needsRetry: false));
      expect(
        f.source.calls.single,
        unorderedEquals([
          ReferenceRateType.lprOneYear,
          ReferenceRateType.lprFiveYearPlus,
        ]),
      );
      expect((await f.records.list('loan')).single.applied, isTrue);
      expect((await f.records.list('other')).single.applied, isTrue);
    },
  );

  test(
    'a failed type leaves only its loan waiting and can retry the same day',
    () async {
      await f.seed(id: 'other', type: ReferenceRateType.lprOneYear);
      f.source.omitted.add(ReferenceRateType.lprOneYear);
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
      expect(f.source.calls.last, [ReferenceRateType.lprOneYear]);
      expect((await f.records.list('other')).single.applied, isTrue);
    },
  );

  for (final type in ReferenceRateType.values) {
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
        final stage = restored.stageTerms.repayments.single;
        expect(stage.floatingRate!.referenceRateType, type);
        expect(stage.rateChanges.single.referenceRate.type, type);
        expect(stage.rateChanges.single.referenceRate.ratePpm, 39000);
        expect(stage.rateChanges.single.rate.ppm, 36000);
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
      final tables = <String, Iterable<BackupJson>>{...snapshot.tables};
      tables['installment_stage_configs'] = [
        for (final row in snapshot.rows('installment_stage_configs'))
          {
            ...row,
            'lprTenor': row['referenceRateType'] == null
                ? null
                : 'fiveYearPlus',
          }..remove('referenceRateType'),
      ];
      tables['installment_repricing_records'] = [
        for (final row in snapshot.rows('installment_repricing_records'))
          {
              ...row,
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
        restored.stageTerms.repayments.single.rateChanges.single.rate.ppm,
        36000,
      );
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
        28000,
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
      expect(after.first.expectedInterest.minorUnits, 28000);
      expect(
        (await f.installments.findContract(
          'loan',
        ))!.stageTerms.repayments.single.rateChanges,
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
    'automatic repricing uses the latest repayment status and plan amounts',
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
      expect(saved.first.status, InstallmentScheduleStatus.paid);
      expect(saved.first.expectedInterest.minorUnits, 500);
      expect(saved.last.expectedInterest.minorUnits, isNot(99));
    },
  );

  test(
    'late repricing automatically revises pending tail and freezes paid prefix',
    () async {
      final rows = await f.installments.listSchedules('loan');
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
      expect(saved.first.expectedInterest, rows.first.expectedInterest);
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
    expect(rows.first.expectedInterest.minorUnits, 28000);
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
      final rows = await f.installments.listSchedules('loan');
      // From an 80000 contract, reducing principal by 20000 means both rate segments use 60000.
      final updates = const InstallmentPlanEngine()
          .recalculate(
            InstallmentPlanContext.fromContract(
              contract: contract,
              schedules: rows,
              prepaymentPrincipal: Money(minorUnits: 2000000),
            ),
            RecalculateAfterPrepayment(DateTime(2026, 1, 10)),
          )
          .recalculatedRows;
      expect(updates.first.interest.minorUnits, 21000);
      expect(
        updates.fold<int>(0, (sum, r) => sum + r.principal.minorUnits),
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
      expect(restored.stageTerms.repayments.single.floatingRate!.spreadBp, -30);
      expect(
        restored.stageTerms.repayments.single.rateChanges.single.rate.ppm,
        36000,
      );
      expect(
        (await f.installments.listSchedules(
          'loan',
        )).first.expectedInterest.minorUnits,
        28000,
      );
      expect((await f.records.list('loan')).single.applied, isTrue);
    },
  );
}

class _Source implements ReferenceRateSource {
  final calls = <List<ReferenceRateType>>[];
  final omitted = <ReferenceRateType>{};
  @override
  String get key => 'fixture';
  @override
  int get order => 100;
  @override
  Set<ReferenceRateType> get supportedTypes => ReferenceRateType.values.toSet();

  final rates = [
    ReferenceRate(
      type: ReferenceRateType.lprFiveYearPlus,
      date: DateTime.utc(2025, 12, 19),
      ratePpm: 39000,
      source: 'fixture',
    ),
  ];

  @override
  Future<Map<ReferenceRateType, List<ReferenceRate>>> fetch(
    List<ReferenceRateType> types, {
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
    runner: DriftTransactionRunner(db),
    idGenerator: _PlanIds(),
  );
  Future<void> seed({
    String id = 'loan',
    ReferenceRateType type = ReferenceRateType.lprFiveYearPlus,
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
    final contract = InstallmentContract(
      id: id,
      liabilityAccountId: 'account',
      sourceType: InstallmentSourceType.disbursement,
      principal: principal,
      borrowingDate: borrowingDate ?? DateTime(2025, 12, 20),
      status: InstallmentContractStatus.active,
      createdAt: borrowingDate ?? DateTime(2025, 12, 20),
      stageTerms: terms,
    );
    final plan = const InstallmentPlanEngine().generate(
      terms.planTerms(contract.principal, contract.borrowingDate),
    );
    await installments.insertAggregate(contract, [
      for (final p in plan.entries)
        InstallmentSchedule(
          id: id == 'loan'
              ? 'period-${p.periodNo}'
              : '$id-period-${p.periodNo}',
          contractId: id,
          stageId: stageId,
          periodNo: p.periodNo,
          expectedRepaymentDate: p.expectedRepaymentDate,
          expectedPrincipal: p.expectedPrincipal,
          expectedInterest: p.expectedInterest,
          expectedFee: p.expectedFee,
          status: InstallmentScheduleStatus.pending,
          createdAt: contract.createdAt,
        ),
    ]);
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
                referenceRateType: ReferenceRateType.lprFiveYearPlus,
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
        type: ReferenceRateType.lprFiveYearPlus,
        date: DateTime.utc(2024, 12, 20),
        ratePpm: 39000,
        source: source.key,
      ),
    );
    final rows = await installments.listSchedules('example');
    for (final row in rows.take(3)) {
      row.markPaid();
    }
    await installments.saveAggregate(
      (await installments.findContract('example'))!,
      rows,
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
        RecalculateAfterPrepayment(date),
      );
    });
  }
}

class _PlanIds implements IdGenerator {
  int next = 0;
  @override
  String newId() => 'plan-${next++}';
}
