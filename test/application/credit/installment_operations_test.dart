import '../../helper/legacy_installment_snapshot.dart';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/installment/command/installment_interest_adjustment_service.dart';
import 'package:smartflow/application/credit/installment/command/installment_plan_service.dart';
import 'package:smartflow/application/credit/installment/command/installment_repricing_service.dart';
import 'package:smartflow/application/credit/installment/command/installment_status_repair_app_service.dart';
import 'package:smartflow/application/credit/reference_rate/reference_rate_service.dart';
import 'package:smartflow/application/data_management/backup/backup_service.dart';
import 'package:smartflow/application/data_management/backup/backup_models.dart';
import 'package:smartflow/application/data_management/backup/installment_backup_migration.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/domain/credit/service/installment/installment_origination_service.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/bill_period.dart';
import 'package:smartflow/domain/credit/valobj/floating_rate.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_change.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_operation.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_terms.dart';
import 'package:smartflow/domain/credit/valobj/interest_rate.dart';
import 'package:smartflow/domain/credit/valobj/repayment_amount_breakdown.dart';
import 'package:smartflow/domain/credit/valobj/repayment_dates_strategy.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_bill_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_interest_adjustment_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_repricing_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_reference_rate_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_repayment_repository.dart';
import 'package:smartflow/infrastructure/data_management/backup/drift_backup_gateway.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import '../../helper/sequential_id_generator.dart';
import '../../helper/test_app_database.dart';

DateTime day(int month, int date) => DateTime(2026, month, date);

void main() {
  late _Fixture f;
  setUp(() {
    f = _Fixture();
  });
  tearDown(() => f.db.close());

  InstallmentContractTerms twoStages({bool reverseStages = false}) =>
      InstallmentContractTerms(
        stages: [
          for (final (id, month, ppm) in [
            (reverseStages ? 'second' : 'first', 9, 36000),
            (reverseStages ? 'first' : 'second', 11, 48000),
          ])
            InstallmentContractStage(
              id: id,
              terms: AmortizingStage(
                dates: IntervalRepaymentDates(
                  firstDate: day(month, 8),
                  count: 2,
                ),
                accrualStartDate: day(month - 1, 8),
                method: InstallmentRepaymentMethod.interestFirst,
                accrual: InterestAccrualMethod.daily,
                rate: InterestRate(ppm: ppm, period: InterestRatePeriod.annual),
              ),
            ),
        ],
      );

  test('each stage generates its own benchmark and stops at its end', () async {
    await f.seed(stageTerms: twoStages());
    for (final date in [day(11, 19), DateTime(2027, 1, 1)]) {
      await f.db
          .into(f.db.referenceRates)
          .insert(
            ReferenceRatesCompanion.insert(
              type: InterestRateType.lprFiveYearPlus.name,
              rateDate: referenceDate(date),
              ratePpm: 40000,
              source: 'fixture',
            ),
          );
    }
    await f.repricing.addConfiguration(
      'loan',
      stageId: 'first',
      effectiveFrom: day(8, 8),
      rule: f.rule(bp: 50),
    );
    // A configuration for the next stage must not close the first stage's window.
    await f.repricing.addConfiguration(
      'loan',
      stageId: 'second',
      effectiveFrom: day(8, 10),
      rule: FloatingRateRule(
        referenceRateType: InterestRateType.lprFiveYearPlus,
        spreadBp: -20,
        firstResetDate: day(11, 20),
        firstEffectiveDate: day(11, 20),
        cycleMonths: 3,
      ),
    );
    expect(await f.repricing.runDue(day(11, 20)), (
      changed: true,
      needsRetry: false,
    ));
    final records = await f.records.list('loan');
    expect(records.map((record) => (record.stageId, record.change.rate.ppm)), [
      ('first', 23000),
      ('second', 38000),
    ]);
    expect(records.map((record) => record.change.effectiveDate), [
      DateTime.utc(2026, 8, 20),
      DateTime.utc(2026, 11, 20),
    ]);
    final rows = await f.installments.listSchedules('loan');
    expect(rows[2].expectedInterest.minorUnits, 41333);
    expect(
      (await f.installments.findContract('loan'))!.repricingConfigurations.map(
        (config) => (config.stageId, config.lastGeneratedDate),
      ),
      [
        ('first', DateTime.utc(2026, 8, 20)),
        ('second', DateTime.utc(2026, 11, 20)),
      ],
    );
  });

  test(
    'another stage same-day fact does not suppress automatic repricing',
    () async {
      await f.seed(stageTerms: twoStages());
      await f.repricing.addConfiguration(
        'loan',
        stageId: 'first',
        effectiveFrom: day(8, 8),
        rule: f.rule(),
      );
      await f.repricing.create(
        'loan',
        stageId: 'second',
        resetDate: day(8, 20),
        effectiveDate: day(8, 20),
        referenceRateType: InterestRateType.lprOneYear,
        spreadBp: 100,
      );
      expect(await f.repricing.runDue(day(8, 20)), (
        changed: true,
        needsRetry: false,
      ));
      final records = await f.records.list('loan');
      expect(records.map((record) => record.stageId).toSet(), {
        'first',
        'second',
      });
      expect(records.map((record) => record.change.rate.ppm).toSet(), {
        18000,
        28000,
      });
      await expectLater(
        f.repricing.create(
          'loan',
          stageId: 'first',
          resetDate: day(8, 20),
          effectiveDate: day(8, 20),
          referenceRateType: InterestRateType.lprOneYear,
          spreadBp: 0,
        ),
        throwsA(isA<BusinessException>()),
      );
      final other = const InstallmentOriginationService().originateDisbursement(
        contractId: 'other',
        liabilityAccountId: 'account',
        terms: InstallmentOriginationTerms(
          principal: const Money(minorUnits: 10000000),
          borrowingDate: day(8, 8),
          stageTerms: f.terms(),
        ),
        createdAt: day(8, 8),
        newScheduleId: f.ids.newId,
      );
      await f.installments.insertAggregate(other.contract, other.schedules);
      for (final stageId in ['missing', 'stage']) {
        await expectLater(
          f.repricing.addConfiguration(
            'loan',
            stageId: stageId,
            effectiveFrom: day(8, 8),
            rule: f.rule(),
          ),
          throwsA(isA<BusinessException>()),
        );
        await expectLater(
          f.repricing.create(
            'loan',
            stageId: stageId,
            resetDate: day(8, 20),
            effectiveDate: day(8, 20),
            referenceRateType: InterestRateType.lprOneYear,
            spreadBp: 0,
          ),
          throwsA(isA<BusinessException>()),
        );
      }
      final snapshot = await DriftBackupGateway(f.db).readSnapshot();
      for (final table in [
        'installment_repricing_configs',
        'installment_repricing_records',
      ]) {
        final broken = [
          for (final row in snapshot.rows(table)) {...row, 'stageId': 'stage'},
        ];
        expect(
          () => BackupService.validateSnapshot(
            snapshot.copyWith(tables: {...snapshot.tables, table: broken}),
          ),
          throwsA(isA<BackupValidationException>()),
        );
      }
    },
  );

  test(
    'reordering stages retains operations by stable stage identity',
    () async {
      await f.seed(stageTerms: twoStages());
      for (final (stageId, bp) in [('first', 0), ('second', 100)]) {
        await f.repricing.create(
          'loan',
          stageId: stageId,
          resetDate: day(8, 20),
          effectiveDate: day(8, 20),
          referenceRateType: InterestRateType.lprOneYear,
          spreadBp: bp,
        );
      }
      final request = RecalculateFromTerms(twoStages(reverseStages: true));
      final preview = await f.plans.previewChange('loan', request);
      await f.plans.confirmChange('loan', request, token: preview.token);
      final rows = await f.installments.listSchedules('loan');
      expect(rows.map((row) => row.stageId), [
        'second',
        'second',
        'first',
        'first',
      ]);
      expect(rows[1].expectedInterest.minorUnits, 23333);
      expect(rows[2].expectedInterest.minorUnits, 15500);
      expect((await f.records.list('loan')).map((row) => row.stageId).toSet(), {
        'first',
        'second',
      });
    },
  );

  test(
    'removing a stage deletes only its operations and rolls back on failure',
    () async {
      await f.seed(stageTerms: twoStages());
      for (final stageId in ['first', 'second']) {
        await f.repricing.addConfiguration(
          'loan',
          stageId: stageId,
          effectiveFrom: day(8, 8),
          rule: f.rule(),
        );
        await f.repricing.create(
          'loan',
          stageId: stageId,
          resetDate: day(8, 20),
          effectiveDate: day(8, 20),
          referenceRateType: InterestRateType.lprOneYear,
          spreadBp: stageId == 'first' ? 0 : 100,
        );
      }
      final request = RecalculateFromTerms(
        InstallmentContractTerms(stages: [twoStages().stages.last]),
      );
      final preview = await f.plans.previewChange('loan', request);
      await f.db.customStatement(
        "CREATE TRIGGER reject_stage BEFORE INSERT ON installment_stage_configs "
        "WHEN NEW.id = 'second' BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      await expectLater(
        f.plans.confirmChange('loan', request, token: preview.token),
        throwsA(isA<Exception>()),
      );
      var contract = (await f.installments.findContract('loan'))!;
      expect(contract.stageTerms.stages, hasLength(2));
      expect(contract.repricingConfigurations, hasLength(2));
      expect(contract.repricings, hasLength(2));
      await f.db.customStatement('DROP TRIGGER reject_stage');
      await f.plans.confirmChange('loan', request, token: preview.token);
      contract = (await f.installments.findContract('loan'))!;
      expect(contract.stageTerms.stages.single.id, 'second');
      expect(contract.repricingConfigurations.single.stageId, 'second');
      expect(contract.repricings.single.stageId, 'second');
      expect(await f.db.select(f.db.referenceRates).get(), hasLength(3));
      expect(
        (await f.installments.listSchedules(
          'loan',
        )).map((row) => row.stageId).toSet(),
        {'second'},
      );
    },
  );

  test(
    'a new configuration on a removed stage invalidates its deletion preview',
    () async {
      await f.seed(stageTerms: twoStages());
      final request = RecalculateFromTerms(
        InstallmentContractTerms(stages: [twoStages().stages.last]),
      );
      final preview = await f.plans.previewChange('loan', request);
      await f.repricing.addConfiguration(
        'loan',
        stageId: 'first',
        effectiveFrom: day(8, 8),
        rule: f.rule(),
      );
      await expectLater(
        f.plans.confirmChange('loan', request, token: preview.token),
        throwsA(isA<BusinessException>()),
      );
      expect(
        (await f.installments.findContract('loan'))!.stageTerms.stages,
        hasLength(2),
      );
    },
  );

  test(
    'v40 backups restore stage ownership while retaining generation progress',
    () async {
      await f.seed();
      await f.configure();
      await f.repricing.runDue(day(8, 20));
      final snapshot = await DriftBackupGateway(f.db).readSnapshot();
      final tables = legacyInstallmentSnapshot(snapshot);
      for (final table in [
        'installment_repricing_configs',
        'installment_repricing_records',
      ]) {
        tables[table] = [
          for (final row in snapshot.rows(table)) {...row}..remove('stageId'),
        ];
      }
      migrateInstallmentBackup(tables, schemaVersion: 40, formatVersion: 2);
      final restored = snapshot.copyWith(tables: tables);
      BackupService.validateSnapshot(restored);
      await DriftBackupGateway(f.db).replaceSnapshot(restored);
      final contract = (await f.installments.findContract('loan'))!;
      expect(contract.repricingConfigurations.single.stageId, 'stage');
      expect(contract.repricings.single.stageId, 'stage');
      expect(
        contract.repricingConfigurations.single.lastGeneratedDate,
        DateTime.utc(2026, 8, 20),
      );
      expect(await f.repricing.runDue(day(8, 20)), (
        changed: false,
        needsRetry: false,
      ));
    },
  );

  test(
    'configuration windows select by reset date and concurrent tasks create one fact',
    () async {
      await f.seed();
      await f.repricing.addConfiguration(
        'loan',
        stageId: 'stage',
        effectiveFrom: day(8, 8),
        rule: f.rule(reset: day(9, 1), effective: day(9, 6)),
      );
      await f.repricing.addConfiguration(
        'loan',
        stageId: 'stage',
        effectiveFrom: day(9, 6),
        rule: f.rule(reset: day(9, 1), effective: day(9, 6), bp: -10),
      );
      final results = await Future.wait([
        f.repricing.runDue(day(9, 1)),
        f.repricing.runDue(day(9, 1)),
      ]);
      expect(results.where((result) => result.changed), hasLength(1));
      expect(results.every((result) => !result.needsRetry), isTrue);
      final records = await f.records.list('loan');
      expect(records, hasLength(1));
      expect(records.single.change.effectiveDate, DateTime.utc(2026, 9, 6));
      expect(records.single.change.spreadBp, 0);
      await expectLater(
        f.repricing.create(
          'loan',
          stageId: 'stage',
          resetDate: day(9, 1),
          effectiveDate: day(9, 6),
          referenceRateType: InterestRateType.lprOneYear,
          spreadBp: 0,
        ),
        throwsA(isA<BusinessException>()),
      );
      expect((await f.repricing.runDue(day(9, 1))).changed, isFalse);
    },
  );

  test(
    'duplicate configuration dates are rejected at the persistence boundary',
    () async {
      await f.seed();
      final outcomes = await Future.wait([
        for (var i = 0; i < 2; i++)
          () async {
            try {
              await f.repricing.addConfiguration(
                'loan',
                stageId: 'stage',
                effectiveFrom: day(8, 8),
                rule: f.rule(),
              );
              return true;
            } on BusinessException {
              return false;
            }
          }(),
      ]);
      expect(outcomes.where((success) => success), hasLength(1));
      expect(
        (await f.installments.findContract('loan'))!.repricingConfigurations,
        hasLength(1),
      );
    },
  );

  test(
    'manual repricing works without configurations and does not create generation progress',
    () async {
      await f.seed();
      await f.repricing.create(
        'loan',
        stageId: 'stage',
        resetDate: day(8, 20),
        effectiveDate: day(8, 20),
        referenceRateType: InterestRateType.lprOneYear,
        spreadBp: -10,
      );
      final record = (await f.records.list('loan')).single;
      expect(record.change.rate.ppm, 17000);
      expect(
        (await f.installments.findContract('loan'))!.repricingConfigurations,
        isEmpty,
      );
      await expectLater(
        f.repricing.create(
          'loan',
          stageId: 'stage',
          resetDate: day(8, 20),
          effectiveDate: day(8, 20),
          referenceRateType: InterestRateType.lprOneYear,
          spreadBp: 0,
        ),
        throwsA(isA<BusinessException>()),
      );
      await f.repricing.delete('loan', record.id);
      expect(await f.records.list('loan'), isEmpty);
      expect(
        (await f.installments.findContract('loan'))!.repricingConfigurations,
        isEmpty,
      );
    },
  );

  test(
    'task treats a manual duplicate as success without requiring reference rates',
    () async {
      await f.seed();
      await f.repricing.create(
        'loan',
        stageId: 'stage',
        resetDate: day(8, 20),
        effectiveDate: day(8, 20),
        referenceRateType: InterestRateType.lprOneYear,
        spreadBp: -10,
      );
      await f.configure();
      expect(
        (await f.installments.findContract(
          'loan',
        ))!.repricingConfigurations.single.lastGeneratedDate,
        isNull,
      );
      await f.db.delete(f.db.referenceRates).go();
      expect(await f.repricing.runDue(day(8, 20)), (
        changed: false,
        needsRetry: false,
      ));
      final record = (await f.records.list('loan')).single;
      expect(record.change.spreadBp, -10);
      expect(
        (await f.installments.findContract(
          'loan',
        ))!.repricingConfigurations.single.lastGeneratedDate,
        DateTime.utc(2026, 8, 20),
      );
      await f.repricing.delete('loan', record.id);
      expect(await f.repricing.runDue(day(8, 20)), (
        changed: false,
        needsRetry: false,
      ));
      expect(await f.records.list('loan'), isEmpty);
    },
  );

  test(
    'manual deletion before task processing leaves the configured cycle due',
    () async {
      await f.seed();
      await f.configure();
      await f.repricing.create(
        'loan',
        stageId: 'stage',
        resetDate: day(8, 20),
        effectiveDate: day(8, 20),
        referenceRateType: InterestRateType.lprOneYear,
        spreadBp: -10,
      );
      await f.repricing.delete(
        'loan',
        (await f.records.list('loan')).single.id,
      );
      expect(
        (await f.installments.findContract(
          'loan',
        ))!.repricingConfigurations.single.lastGeneratedDate,
        isNull,
      );
      expect(await f.repricing.runDue(day(8, 20)), (
        changed: true,
        needsRetry: false,
      ));
      expect((await f.records.list('loan')).single.change.spreadBp, 0);
    },
  );

  test(
    'a missing earlier cycle cannot be skipped by a later successful cycle',
    () async {
      await f.seed();
      await f.configure();
      final lateRate = ReferenceRate(
        type: InterestRateType.lprOneYear,
        date: DateTime.utc(2026, 11, 19),
        ratePpm: 15000,
        source: 'fixture',
      );
      expect(
        await f.repricing.prepare(
          'loan',
          day(11, 20),
          resolvedRates: {
            (InterestRateType.lprOneYear, DateTime.utc(2026, 8, 19)): null,
            (InterestRateType.lprOneYear, DateTime.utc(2026, 11, 19)): lateRate,
          },
        ),
        isFalse,
      );
      expect(await f.records.list('loan'), isEmpty);
      expect(
        (await f.installments.findContract(
          'loan',
        ))!.repricingConfigurations.single.lastGeneratedDate,
        isNull,
      );
      expect(
        await f.repricing.prepare(
          'loan',
          day(11, 20),
          resolvedRates: {
            (
              InterestRateType.lprOneYear,
              DateTime.utc(2026, 8, 19),
            ): ReferenceRate(
              type: InterestRateType.lprOneYear,
              date: DateTime.utc(2026, 8, 19),
              ratePpm: 18000,
              source: 'fixture',
            ),
            (InterestRateType.lprOneYear, DateTime.utc(2026, 11, 19)): lateRate,
          },
        ),
        isTrue,
      );
      expect(await f.records.list('loan'), hasLength(2));
      expect(
        (await f.installments.findContract(
          'loan',
        ))!.repricingConfigurations.single.lastGeneratedDate,
        DateTime.utc(2026, 11, 20),
      );
    },
  );

  test(
    'each configuration advances independently within its own effective window',
    () async {
      await f.seed();
      await f.configure();
      await f.repricing.addConfiguration(
        'loan',
        stageId: 'stage',
        effectiveFrom: day(11, 1),
        rule: f.rule(reset: day(11, 20), effective: day(11, 20), bp: -10),
      );
      expect(
        await f.repricing.prepare(
          'loan',
          day(11, 20),
          resolvedRates: {
            (
              InterestRateType.lprOneYear,
              DateTime.utc(2026, 11, 19),
            ): ReferenceRate(
              type: InterestRateType.lprOneYear,
              date: DateTime.utc(2026, 11, 19),
              ratePpm: 18000,
              source: 'fixture',
            ),
          },
        ),
        isFalse,
      );
      final configs = (await f.installments.findContract(
        'loan',
      ))!.repricingConfigurations;
      expect(configs.map((config) => config.lastGeneratedDate), [
        null,
        DateTime.utc(2026, 11, 20),
      ]);
      expect((await f.records.list('loan')).single.change.spreadBp, -10);
      await f.repricing.runDue(day(11, 20));
      final updated = (await f.installments.findContract(
        'loan',
      ))!.repricingConfigurations;
      expect(updated.map((config) => config.lastGeneratedDate), [
        DateTime.utc(2026, 8, 20),
        DateTime.utc(2026, 11, 20),
      ]);
      expect(await f.records.list('loan'), hasLength(2));
    },
  );

  test(
    'record creation and generation progress roll back together and can retry',
    () async {
      await f.seed();
      await f.configure();
      await f.db.customStatement(
        'CREATE TRIGGER reject_progress BEFORE UPDATE ON installment_repricing_configs '
        "BEGIN SELECT RAISE(ABORT, 'test progress failure'); END",
      );
      await expectLater(
        f.repricing.prepare('loan', day(8, 20)),
        throwsA(isA<Exception>()),
      );
      expect(await f.records.list('loan'), isEmpty);
      expect(
        (await f.installments.findContract(
          'loan',
        ))!.repricingConfigurations.single.lastGeneratedDate,
        isNull,
      );
      await f.db.customStatement('DROP TRIGGER reject_progress');
      expect(await f.repricing.runDue(day(8, 20)), (
        changed: true,
        needsRetry: false,
      ));
      expect(await f.records.list('loan'), hasLength(1));
    },
  );

  test(
    'interest adjustments use final repriced segments, keep principal and support edit/delete',
    () async {
      await f.seed();
      await f.configure();
      await f.repricing.runDue(day(8, 20));
      final before = await f.installments.listSchedules('loan');
      expect(before.first.expectedInterest.minorUnits, 21000);
      final id = await f.adjustments.save(
        'loan',
        InterestAdjustment(
          start: day(8, 15),
          end: day(8, 25),
          ratioPpm: 500000,
        ),
      );
      final adjusted = await f.installments.listSchedules('loan');
      expect(adjusted.first.expectedInterest.minorUnits, 17250);
      expect(
        adjusted.map((row) => row.expectedPrincipal),
        before.map((row) => row.expectedPrincipal),
      );
      await f.adjustments.save(
        'loan',
        InterestAdjustment(start: day(8, 15), end: day(8, 25), ratioPpm: 0),
        id: id,
      );
      expect(
        (await f.installments.listSchedules(
          'loan',
        )).first.expectedInterest.minorUnits,
        13500,
      );
      expect(
        (await f.installments.findContract(
          'loan',
        ))!.interestAdjustments.single.id,
        id,
      );
      await f.adjustments.delete('loan', id);
      expect(
        (await f.installments.listSchedules(
          'loan',
        )).first.expectedInterest.minorUnits,
        21000,
      );
    },
  );

  test(
    'monthly partial intervals roll back, adjacent full units save and overlaps do not',
    () async {
      await f.seed(accrual: InterestAccrualMethod.monthly);
      final before = await f.installments.listSchedules('loan');
      await expectLater(
        f.adjustments.save(
          'loan',
          InterestAdjustment(start: day(8, 20), end: day(9, 1), ratioPpm: 0),
        ),
        throwsA(isA<BusinessException>()),
      );
      expect(
        (await f.installments.findContract('loan'))!.interestAdjustments,
        isEmpty,
      );
      expect(
        (await f.installments.listSchedules(
          'loan',
        )).map((row) => row.expectedInterest),
        before.map((row) => row.expectedInterest),
      );
      await f.adjustments.save(
        'loan',
        InterestAdjustment(start: day(8, 9), end: day(9, 9), ratioPpm: 0),
      );
      await f.adjustments.save(
        'loan',
        InterestAdjustment(start: day(9, 9), end: day(10, 9), ratioPpm: 500000),
      );
      await expectLater(
        f.adjustments.save(
          'loan',
          InterestAdjustment(
            start: day(8, 9),
            end: day(10, 9),
            ratioPpm: 1000000,
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
      expect(
        (await f.installments.findContract('loan'))!.interestAdjustments,
        hasLength(2),
      );
    },
  );

  test(
    'mid-month repricing makes a partial monthly adjustment valid',
    () async {
      await f.seed(accrual: InterestAccrualMethod.monthly);
      await f.configure();
      await f.repricing.create(
        'loan',
        stageId: 'stage',
        resetDate: day(8, 20),
        effectiveDate: day(8, 20),
        referenceRateType: InterestRateType.lprOneYear,
        spreadBp: 0,
      );
      await f.adjustments.save(
        'loan',
        InterestAdjustment(start: day(8, 20), end: day(9, 1), ratioPpm: 0),
      );
      expect(
        (await f.installments.listSchedules(
          'loan',
        )).first.expectedInterest.minorUnits,
        15000,
      );
    },
  );

  test(
    'failure after recording an adjustment rolls back both the record and the replaced plan',
    () async {
      await f.seed();
      final before = await f.installments.listSchedules('loan');
      await f.db.customStatement(
        "CREATE TRIGGER fail_plan BEFORE INSERT ON installment_schedules BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      await expectLater(
        f.adjustments.save(
          'loan',
          InterestAdjustment(start: day(8, 8), end: day(9, 8), ratioPpm: 0),
        ),
        throwsA(isA<Exception>()),
      );
      expect(
        (await f.installments.findContract('loan'))!.interestAdjustments,
        isEmpty,
      );
      expect(
        (await f.installments.listSchedules(
          'loan',
        )).map((row) => row.expectedInterest),
        before.map((row) => row.expectedInterest),
      );
    },
  );

  test(
    'ordinary repayment and old statuses do not freeze a backdated principal reduction',
    () async {
      await f.seed(method: InstallmentRepaymentMethod.equalPrincipal);
      final original = await f.installments.listSchedules('loan');
      await f.pay(original.first);
      await f.repair.validateAndRepair('loan');
      expect(
        (await f.installments.listSchedules('loan')).first.status,
        InstallmentScheduleStatus.paid,
      );
      await f.prepay(day(8, 20), 2000000);
      await f.plans.applyAutomaticChange(
        'loan',
        const RecalculateFromOperations(),
      );
      final result = await f.installments.listSchedules('loan');
      expect(
        result.map((row) => row.expectedPrincipal.minorUnits),
        everyElement(2000000),
      );
      expect(result.first.status, InstallmentScheduleStatus.paid);
      final payment = await f.repayments.findRepayment(
        'payment-${original.first.id}',
      );
      expect(payment!.totalAllocated().principal.minorUnits, 2500000);
      expect(payment.repaymentDate, original.first.expectedRepaymentDate);
      expect(
        (await f.bills.findBill(
          'bill-${original.first.id}',
        ))!.items.single.scheduleId,
        result.first.id,
      );
    },
  );

  test(
    'a settled contract can be repriced without restoring schedule statuses',
    () async {
      await f.seed(method: InstallmentRepaymentMethod.equalPrincipal);
      for (final schedule in await f.installments.listSchedules('loan')) {
        await f.pay(schedule);
      }
      await f.repair.validateAndRepair('loan');
      expect(
        (await f.installments.findContract('loan'))!.status,
        InstallmentContractStatus.settled,
      );
      await f.configure();
      expect((await f.repricing.runDue(day(8, 20))).changed, isTrue);
      expect(
        (await f.installments.findContract('loan'))!.status,
        InstallmentContractStatus.settled,
      );
      expect(
        (await f.installments.listSchedules(
          'loan',
        )).first.expectedInterest.minorUnits,
        21000,
      );
    },
  );

  test(
    'removed schedules retain bill and repayment facts with detached historical projections',
    () async {
      await f.seed(method: InstallmentRepaymentMethod.equalPrincipal);
      final original = await f.installments.listSchedules('loan');
      await f.pay(original.last);
      await f.repair.validateAndRepair('loan');
      final revised = f.terms(
        method: InstallmentRepaymentMethod.equalPrincipal,
        count: 2,
      );
      final preview = await f.plans.previewChange(
        'loan',
        RecalculateFromTerms(revised),
      );
      await f.plans.confirmChange(
        'loan',
        RecalculateFromTerms(revised),
        token: preview.token,
      );
      expect(await f.installments.listSchedules('loan'), hasLength(2));
      final item = (await f.bills.findBill(
        'bill-${original.last.id}',
      ))!.items.single;
      expect(item.scheduleId, isNull);
      expect(item.contractId, 'loan');
      expect(
        (await f.repayments.findRepayment(
          'payment-${original.last.id}',
        ))!.items.single.billItemId,
        item.id,
      );
      expect((await f.repair.validateAndRepair('loan')).issues, isEmpty);
      BackupService.validateSnapshot(
        await DriftBackupGateway(f.db).readSnapshot(),
      );
    },
  );

  test(
    'custom contracts keep every manual amount and date through all operation mutations',
    () async {
      await f.seed(method: InstallmentRepaymentMethod.custom);
      final contract = (await f.installments.findContract('loan'))!;
      final rows = await f.installments.listSchedules('loan');
      for (final row in rows) {
        row.reviseExpectation(
          expectedPrincipal: const Money(minorUnits: 12345),
          expectedInterest: const Money(minorUnits: 789),
        );
      }
      await f.installments.saveAggregate(contract, rows);
      await f.prepay(day(8, 20), 2000000);
      await f.plans.applyAutomaticChange(
        'loan',
        const RecalculateFromOperations(),
      );
      await f.configure();
      await f.repricing.runDue(day(8, 20));
      final adjustment = await f.adjustments.save(
        'loan',
        InterestAdjustment(start: day(8, 15), end: day(9, 1), ratioPpm: 0),
      );
      await f.adjustments.delete('loan', adjustment);
      await f.repricing.delete(
        'loan',
        (await f.records.list('loan')).single.id,
      );
      await f.repayments.deleteRepayment('prepayment');
      await f.plans.applyAutomaticChange(
        'loan',
        const RecalculateFromOperations(),
      );
      final after = await f.installments.listSchedules('loan');
      expect(
        after.map(
          (row) => (
            row.id,
            row.expectedRepaymentDate,
            row.expectedPrincipal,
            row.expectedInterest,
          ),
        ),
        rows.map(
          (row) => (
            row.id,
            row.expectedRepaymentDate,
            row.expectedPrincipal,
            row.expectedInterest,
          ),
        ),
      );
    },
  );

  test(
    'generation progress survives deletion, database reopen and backup restore',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartflow-operations-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/loan.sqlite');
      var database = AppDatabase(NativeDatabase(file));
      addTearDown(() => database.close());
      var instance = _Fixture(database);
      await instance.seed();
      await instance.configure();
      await instance.repricing.runDue(day(8, 20));
      await instance.repricing.delete(
        'loan',
        (await instance.records.list('loan')).single.id,
      );
      await database.close();
      database = AppDatabase(NativeDatabase(file));
      instance = _Fixture(database);
      expect((await instance.repricing.runDue(day(8, 20))).changed, isFalse);
      expect(await instance.records.list('loan'), isEmpty);
      final snapshot = await DriftBackupGateway(database).readSnapshot();
      BackupService.validateSnapshot(snapshot);
      expect(
        snapshot
            .rows('installment_repricing_configs')
            .single['lastGeneratedDate'],
        DateTime.utc(2026, 8, 20).millisecondsSinceEpoch,
      );
      await DriftBackupGateway(f.db).replaceSnapshot(snapshot);
      expect((await f.repricing.runDue(day(8, 20))).changed, isFalse);
      await instance.repricing.create(
        'loan',
        stageId: 'stage',
        resetDate: day(8, 20),
        effectiveDate: day(8, 20),
        referenceRateType: InterestRateType.lprOneYear,
        spreadBp: 0,
      );
      expect(await instance.records.list('loan'), hasLength(1));
    },
  );

  test(
    'custom stage restructuring preserves manual amounts and remaps every stage reference',
    () async {
      await f.seed(method: InstallmentRepaymentMethod.custom);
      final contract = (await f.installments.findContract('loan'))!;
      final rows = await f.installments.listSchedules('loan');
      for (final row in rows) {
        row.reviseExpectation(
          expectedPrincipal: Money(minorUnits: row.periodNo * 100000),
          expectedInterest: Money(minorUnits: row.periodNo * 123),
        );
      }
      await f.installments.saveAggregate(contract, rows);
      final request = RecalculateFromTerms(
        InstallmentContractTerms(
          stages: [
            for (final (id, month) in [('first', 9), ('second', 11)])
              InstallmentContractStage(
                id: id,
                terms: AmortizingStage(
                  method: InstallmentRepaymentMethod.custom,
                  dates: IntervalRepaymentDates(
                    firstDate: day(month, 8),
                    count: 2,
                  ),
                ),
              ),
          ],
        ),
      );
      final preview = await f.plans.previewChange('loan', request);
      await f.plans.confirmChange('loan', request, token: preview.token);
      final saved = await f.installments.listSchedules('loan');
      final stages = (await f.installments.findContract(
        'loan',
      ))!.stageTerms.stages;
      expect(saved.map((row) => row.stageId), [
        stages[0].id,
        stages[0].id,
        stages[1].id,
        stages[1].id,
      ]);
      expect(
        saved.map(
          (row) => (
            row.expectedPrincipal,
            row.expectedInterest,
            row.expectedRepaymentDate,
          ),
        ),
        rows.map(
          (row) => (
            row.expectedPrincipal,
            row.expectedInterest,
            row.expectedRepaymentDate,
          ),
        ),
      );
    },
  );

  test(
    'backup retains operation facts and rejects invalid dates, progress and overlapping adjustments',
    () async {
      await f.seed();
      await f.configure();
      await f.repricing.runDue(day(8, 20));
      await f.adjustments.save(
        'loan',
        InterestAdjustment(
          start: day(8, 15),
          end: day(8, 25),
          ratioPpm: 500000,
        ),
      );
      final snapshot = await DriftBackupGateway(f.db).readSnapshot();
      BackupService.validateSnapshot(snapshot);
      final target = createTestDatabase();
      addTearDown(target.close);
      await DriftBackupGateway(target).replaceSnapshot(snapshot);
      final restored = (await DriftInstallmentRepository(
        target,
      ).findContract('loan'))!;
      expect(restored.interestAdjustments.single.adjustment.ratioPpm, 500000);
      expect(
        restored.repricingConfigurations.single.lastGeneratedDate,
        DateTime.utc(2026, 8, 20),
      );
      expect(
        (await DriftInstallmentRepository(
          target,
        ).listSchedules('loan')).first.expectedInterest.minorUnits,
        17250,
      );
      final config = snapshot.rows('installment_repricing_configs').single;
      final record = snapshot.rows('installment_repricing_records').single;
      final adjustment = snapshot
          .rows('installment_interest_adjustments')
          .single;
      for (final (table, rows) in <(String, List<BackupJson>)>[
        (
          'installment_repricing_configs',
          [
            {
              ...config,
              'lastGeneratedDate': DateTime.utc(
                2026,
                8,
                1,
              ).millisecondsSinceEpoch,
            },
          ],
        ),
        (
          'installment_repricing_configs',
          [
            {
              ...config,
              'lastGeneratedDate': DateTime.utc(
                2026,
                8,
                20,
                12,
              ).millisecondsSinceEpoch,
            },
          ],
        ),
        (
          'installment_repricing_records',
          [
            {
              ...record,
              'effectiveDate': DateTime.utc(
                2026,
                8,
                20,
                12,
              ).millisecondsSinceEpoch,
            },
          ],
        ),
        (
          'installment_interest_adjustments',
          [
            {
              ...adjustment,
              'startDate': DateTime.utc(2026, 8, 15, 12).millisecondsSinceEpoch,
            },
          ],
        ),
        (
          'installment_interest_adjustments',
          [
            adjustment,
            {...adjustment, 'id': 'overlap'},
          ],
        ),
      ]) {
        expect(
          () => BackupService.validateSnapshot(
            snapshot.copyWith(tables: {...snapshot.tables, table: rows}),
          ),
          throwsA(isA<BackupValidationException>()),
        );
      }
    },
  );
}

class _Fixture {
  _Fixture([AppDatabase? database]) : db = database ?? createTestDatabase();
  final AppDatabase db;
  final ids = SequentialIdGenerator();
  late final installments = DriftInstallmentRepository(db);
  late final repayments = DriftRepaymentRepository(db);
  late final bills = DriftBillRepository(db);
  late final runner = DriftTransactionRunner(db);
  late final records = DriftInstallmentRepricingRepository(db);
  late final plans = InstallmentPlanService(
    installments: installments,
    repayments: repayments,
    bills: bills,
    runner: runner,
    idGenerator: ids,
  );
  late final repair = InstallmentStatusRepairAppService(
    installments: installments,
    bills: bills,
    repayments: repayments,
    transactionRunner: runner,
  );
  late final repricing = InstallmentRepricingService(
    installments: installments,
    records: records,
    plans: plans,
    runner: runner,
    referenceRates: ReferenceRateService(
      repository: DriftReferenceRateRepository(db),
      sources: [],
      runner: runner,
      clock: () => DateTime(2027, 1, 1),
    ),
  );
  late final adjustments = InstallmentInterestAdjustmentService(
    installments: installments,
    records: DriftInstallmentInterestAdjustmentRepository(db),
    plans: plans,
    runner: runner,
    ids: ids,
  );

  FloatingRateRule rule({DateTime? reset, DateTime? effective, int bp = 0}) =>
      FloatingRateRule(
        referenceRateType: InterestRateType.lprOneYear,
        spreadBp: bp,
        cycleMonths: 3,
        firstResetDate: reset ?? day(8, 20),
        firstEffectiveDate: effective ?? day(8, 20),
      );
  Future<void> configure() => repricing.addConfiguration(
    'loan',
    stageId: 'stage',
    effectiveFrom: day(8, 8),
    rule: rule(),
  );

  InstallmentContractTerms terms({
    InstallmentRepaymentMethod method =
        InstallmentRepaymentMethod.interestFirst,
    InterestAccrualMethod accrual = InterestAccrualMethod.daily,
    int count = 4,
  }) => InstallmentContractTerms(
    stages: [
      InstallmentContractStage(
        id: 'stage',
        terms: AmortizingStage(
          dates: IntervalRepaymentDates(firstDate: day(9, 8), count: count),
          method: method,
          accrual: accrual,
          rate: const InterestRate(
            ppm: 36000,
            period: InterestRatePeriod.annual,
          ),
        ),
      ),
    ],
  );

  Future<void> seed({
    InstallmentContractTerms? stageTerms,
    InstallmentRepaymentMethod method =
        InstallmentRepaymentMethod.interestFirst,
    InterestAccrualMethod accrual = InterestAccrualMethod.daily,
  }) async {
    await db.customStatement(
      "INSERT INTO accounts (id, name, account_type, account_subtype, account_profile_key) VALUES ('account', '贷款', 'liability', 'loan', 'credit.loan')",
    );
    for (final record in [
      (day(8, 1), 36000),
      (day(8, 19), 18000),
      (DateTime(2027, 1, 1), 18000),
    ]) {
      await db
          .into(db.referenceRates)
          .insert(
            ReferenceRatesCompanion.insert(
              type: InterestRateType.lprOneYear.name,
              rateDate: referenceDate(record.$1),
              ratePpm: record.$2,
              source: 'fixture',
            ),
          );
    }
    final aggregate = const InstallmentOriginationService()
        .originateDisbursement(
          contractId: 'loan',
          liabilityAccountId: 'account',
          terms: InstallmentOriginationTerms(
            principal: const Money(minorUnits: 10000000),
            borrowingDate: day(8, 8),
            stageTerms: stageTerms ?? terms(method: method, accrual: accrual),
          ),
          createdAt: day(8, 8),
          newScheduleId: ids.newId,
        );
    await installments.insertAggregate(aggregate.contract, aggregate.schedules);
  }

  Future<void> prepay(DateTime date, int amount) => repayments.saveRepayment(
    Repayment(
      id: 'prepayment',
      repaymentType: RepaymentType.prepayment,
      targetType: RepaymentTargetType.contract,
      targetId: 'loan',
      repaymentDate: date,
      items: [
        RepaymentItem(
          id: 'prepayment-item',
          repaymentId: 'prepayment',
          allocated: _amount(Money(minorUnits: amount)),
        ),
      ],
    ),
  );

  Future<void> pay(InstallmentSchedule schedule) async {
    final billId = 'bill-${schedule.id}',
        itemId = 'bill-item-${schedule.id}',
        repaymentId = 'payment-${schedule.id}';
    final bill = Bill(
      id: billId,
      accountId: 'account',
      period: BillPeriod.fromDate(schedule.expectedRepaymentDate),
      status: BillStatus.billed,
      items: [
        BillItem(
          id: itemId,
          billId: billId,
          itemType: BillItemType.installment,
          repaymentDate: schedule.expectedRepaymentDate,
          contractId: 'loan',
          scheduleId: schedule.id,
          expectedPrincipal: schedule.expectedPrincipal,
          expectedInterest: schedule.expectedInterest,
          expectedFee: schedule.expectedFee,
          status: BillItemStatus.pending,
        ),
      ],
    );
    await bills.saveBill(bill);
    await bills.replaceBillItems(billId, bill.items);
    await repayments.saveRepayment(
      Repayment(
        id: repaymentId,
        repaymentType: RepaymentType.bill,
        targetType: RepaymentTargetType.bill,
        targetId: billId,
        repaymentDate: schedule.expectedRepaymentDate,
        items: [
          RepaymentItem(
            id: 'allocation-${schedule.id}',
            repaymentId: repaymentId,
            billItemId: itemId,
            allocated: _amount(schedule.expectedPrincipal),
          ),
        ],
      ),
    );
  }

  RepaymentAmountBreakdown _amount(Money principal) => RepaymentAmountBreakdown(
    principal: principal,
    interest: Money.zero(),
    fee: Money.zero(),
    discount: Money.zero(),
  );
}
