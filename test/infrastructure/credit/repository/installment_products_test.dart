import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/product/installment_product_service.dart';
import 'package:smartflow/application/data_management/backup/backup_models.dart';
import 'package:smartflow/application/data_management/backup/backup_service.dart';
import 'package:smartflow/application/data_management/backup/installment_backup_migration.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/money/rounding_mode.dart';
import 'package:smartflow/domain/credit/entity/installment_product.dart';
import 'package:smartflow/domain/credit/service/installment/installment_origination_service.dart';
import 'package:smartflow/domain/credit/service/installment/installment_prepayment_recalculator.dart';
import 'package:smartflow/domain/credit/valobj/day_count_convention.dart';
import 'package:smartflow/domain/credit/valobj/equal_installment_amount.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_terms.dart';
import 'package:smartflow/domain/credit/valobj/installment_stage_rule.dart';
import 'package:smartflow/domain/credit/valobj/interest_rate.dart';
import 'package:smartflow/domain/credit/valobj/repayment_dates_strategy.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_product_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_repository.dart';
import 'package:smartflow/infrastructure/data_management/backup/drift_backup_gateway.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import '../../../helper/test_app_database.dart';
import '../../../helper/sequential_id_generator.dart';

void main() {
  late AppDatabase db;
  late DriftInstallmentProductRepository products;
  late DriftInstallmentRepository contracts;
  setUp(() {
    db = createTestDatabase();
    products = DriftInstallmentProductRepository(db);
    contracts = DriftInstallmentRepository(db);
  });
  tearDown(() => db.close());

  test(
    'current schema stores no contract stage fields and missing stages fail instead of falling back',
    () async {
      final columns =
          (await db
                  .customSelect('PRAGMA table_info(installment_contracts)')
                  .get())
              .map((row) => row.read<String>('name'))
              .toSet();
      expect(
        columns.intersection({
          'total_periods',
          'first_repayment_date',
          'last_repayment_date',
          'repayment_method',
          'interest_rate_period',
          'interest_rate_ppm',
          'interest_accrual_method',
          'total_fee_minor',
        }),
        isEmpty,
      );
      final loan = _loan();
      await contracts.insertAggregate(loan.contract, loan.schedules);
      await db.customStatement(
        "DELETE FROM installment_stage_configs WHERE owner_type = 'contract'",
      );
      await expectLater(
        contracts.findContract('loan'),
        throwsA(isA<BusinessException>()),
      );
    },
  );

  test(
    'format two migration discards stale scalar fields and preserves stage values',
    () {
      final stage = <String, Object?>{
        'id': 's',
        'ownerType': 'contract',
        'ownerId': 'c',
        'stageKind': 'repayment',
        'repaymentMethod': 'interestFirst',
        'periods': 12,
        'ratePpm': 12000,
      };
      final tables = <String, Iterable<BackupJson>>{
        'installment_contracts': [
          {
            'id': 'c',
            'principalMinor': 10000,
            'totalPeriods': 999,
            'interestRatePpm': 99999,
            'repaymentMethod': 'equalPrincipal',
          },
        ],
        'installment_stage_configs': [stage],
      };
      migrateInstallmentBackup(tables, schemaVersion: 32, formatVersion: 2);
      expect(tables['installment_contracts']!.single, {
        'id': 'c',
        'principalMinor': 10000,
      });
      expect(tables['installment_stage_configs']!.single, same(stage));
    },
  );

  test(
    'product rows contain only stable rules and enforce absence of variable data',
    () async {
      await products.save(_product());
      final rows = await db.select(db.installmentStageConfigs).get();
      expect(rows, hasLength(3));
      for (final row in rows) {
        expect([
          row.periods,
          row.ratePpm,
          row.endPrincipalMinor,
          row.fixedAmountMinor,
          row.feeMinor,
          row.untilDate,
          row.firstDate,
          row.lastDate,
          row.accrualStartDate,
        ], everyElement(isNull));
      }
      for (final field in [
        'periods',
        'rate_ppm',
        'end_principal_minor',
        'fixed_amount_minor',
        'fee_minor',
        'until_date',
        'first_date',
        'last_date',
        'accrual_start_date',
      ]) {
        await expectLater(
          db.customStatement(
            "UPDATE installment_stage_configs SET $field = 1 WHERE id = 'p2'",
          ),
          throwsA(isA<Exception>()),
        );
      }
      expect(
        (await products.find('product'))!.stages[1].ratePeriod,
        InterestRatePeriod.annual,
      );
      expect(
        await db
            .customSelect(
              "PRAGMA foreign_key_list('installment_stage_configs')",
            )
            .get(),
        isEmpty,
      );
    },
  );

  test(
    'contract stages survive product edits, roundtrip, and backup restore',
    () async {
      await products.save(_product());
      final loan = _loan();
      await contracts.insertAggregate(loan.contract, loan.schedules);
      await products.save(
        _product(
          name: '新版产品',
          method: InstallmentRepaymentMethod.equalPrincipal,
        ),
      );
      final loaded = (await contracts.findContract('loan'))!;
      expect(loaded.productName, '原产品');
      expect(loaded.stageTerms.stages, hasLength(3));
      expect(
        (loaded.stageTerms.stages[1].terms as AmortizingStage).method,
        InstallmentRepaymentMethod.interestFirst,
      );
      final finalStage = loaded.stageTerms.repayments.last;
      expect(
        finalStage.installmentAmount,
        const EqualInstallmentAmount.fixed(Money(minorUnits: 6000)),
      );
      expect(loaded.stageTerms.dayCount, DayCountConvention.thirty365);
      expect(loaded.stageTerms.rounding, RoundingMode.halfEven);
      final schedules = await contracts.listSchedules('loan');
      expect(schedules.map((s) => s.stageId), ['c2', 'c2', 'c3', 'c3']);
      final before = const InstallmentPrepaymentRecalculator().recalculate(
        contract: loaded,
        schedules: schedules,
        prepaymentPrincipalMinor: 1000,
      );
      final gateway = DriftBackupGateway(db);
      final snapshot = await gateway.readSnapshot();
      await gateway.replaceSnapshot(snapshot);
      final restored = (await contracts.findContract('loan'))!;
      final after = const InstallmentPrepaymentRecalculator().recalculate(
        contract: restored,
        schedules: await contracts.listSchedules('loan'),
        prepaymentPrincipalMinor: 1000,
      );
      expect(
        after.map((r) => r.expectedPrincipal),
        before.map((r) => r.expectedPrincipal),
      );
      expect(
        after.map((r) => r.expectedInterest),
        before.map((r) => r.expectedInterest),
      );
      expect(restored.productName, '原产品');
    },
  );

  test(
    'referenced products archive instead of deletion and invalid save is atomic',
    () async {
      await products.save(_product());
      final loan = _loan();
      await contracts.insertAggregate(loan.contract, loan.schedules);
      final service = InstallmentProductServiceImpl(
        repository: products,
        runner: DriftTransactionRunner(db),
        ids: SequentialIdGenerator(prefix: 'p'),
      );
      await expectLater(
        service.delete('product'),
        throwsA(isA<BusinessException>()),
      );
      await service.setArchived('product', true);
      expect((await products.find('product'))!.archived, isTrue);
      await expectLater(
        service.save(
          id: 'product',
          name: '损坏',
          stages: [],
          dayCount: DayCountConvention.thirty360,
          rounding: RoundingMode.halfUp,
        ),
        throwsA(isA<BusinessException>()),
      );
      expect((await products.find('product'))!.name, '原产品');
      await contracts.deleteContract('loan');
      expect(
        await (db.select(
          db.installmentStageConfigs,
        )..where((s) => s.ownerType.equals('contract'))).get(),
        isEmpty,
      );
      await service.delete('product');
      expect(await db.select(db.installmentStageConfigs).get(), isEmpty);
    },
  );

  for (final schemaVersion in [29, 30, 31]) {
    test(
      'format one schema $schemaVersion backups restore stages and repayment dates',
      () async {
        await db.customStatement(
          "INSERT INTO accounts (id, name, account_type, account_subtype, account_profile_key) "
          "VALUES ('liability', '贷款', 'liability', 'loan', 'credit.loan')",
        );
        var next = 0;
        final loan = const InstallmentOriginationService()
            .originateDisbursement(
              contractId: 'old',
              liabilityAccountId: 'liability',
              createdAt: DateTime(2026),
              newScheduleId: () => 'old-${next++}',
              terms: InstallmentOriginationTerms(
                principal: const Money(minorUnits: 10000),
                borrowingDate: DateTime(2026),
                stageTerms: InstallmentContractTerms.singleStage(
                  id: 'stage-1',
                  totalPeriods: 2,
                  firstDate: DateTime(2026, 2),
                  method: InstallmentRepaymentMethod.equalPrincipal,
                  accrual: InterestAccrualMethod.monthly,
                  feeMinor: 0,
                ),
              ),
            );
        await contracts.insertAggregate(loan.contract, loan.schedules);
        final createdAt = DateTime(2026, 1, 20);
        final paidAt = DateTime(2026, 1, 10);
        await db.customStatement(
          "INSERT INTO transactions (id, business_purpose, occurred_at, posted_at, primary_amount_minor, source_kind) "
          "VALUES ('repayment-tx', 'debtRepayment', ?, ?, 100, 'manual')",
          [
            paidAt.millisecondsSinceEpoch ~/ 1000,
            createdAt.millisecondsSinceEpoch ~/ 1000,
          ],
        );
        await db.customStatement(
          "INSERT INTO accounts (id, name, account_type, account_subtype, balance_minor) "
          "VALUES ('cash-account', '现金', 'asset', 'fund', -100)",
        );
        await db.customStatement(
          "UPDATE accounts SET balance_minor = -100 WHERE id = 'liability'",
        );
        await db.customStatement(
          "INSERT INTO entries (id, transaction_id, account_id, direction, amount_minor) VALUES "
          "('debit', 'repayment-tx', 'liability', 'debit', 100), "
          "('credit', 'repayment-tx', 'cash-account', 'credit', 100)",
        );
        for (final id in ['cash', 'offline', 'fallback']) {
          await db
              .into(db.repayments)
              .insert(
                RepaymentsCompanion.insert(
                  id: id,
                  repaymentType: 'PREPAYMENT',
                  targetType: 'CONTRACT',
                  targetId: 'old',
                  transactionId: Value(id == 'cash' ? 'repayment-tx' : null),
                  repaymentDate: id == 'fallback' ? createdAt : paidAt,
                  createdAt: Value(createdAt),
                ),
              );
        }
        final gateway = DriftBackupGateway(db);
        final snapshot = await gateway.readSnapshot();
        final files = <String, Uint8List>{};
        final descriptors = <BackupFileDescriptor>[];
        void add(String table, String path, String content, int count) {
          final bytes = Uint8List.fromList(utf8.encode(content));
          files[path] = bytes;
          descriptors.add(
            BackupFileDescriptor(
              table: table,
              path: path,
              rowCount: count,
              byteCount: bytes.length,
              sha256: sha256.convert(bytes).toString(),
            ),
          );
        }

        for (final table in BackupTables.all.where(
          (t) =>
              t != 'installment_products' && t != 'installment_stage_configs',
        )) {
          final rows = [
            for (final row in snapshot.rows(table)) {...row},
          ];
          if (table == 'installment_contracts') {
            for (final row in rows) {
              row.addAll({
                'totalPeriods': 2,
                'firstRepaymentDate': DateTime(2026, 2).millisecondsSinceEpoch,
                'lastRepaymentDate': DateTime(2026, 3).millisecondsSinceEpoch,
                'repaymentMethod': 'equalPrincipal',
                'interestAccrualMethod': 'monthly',
                'interestRatePeriod': null,
                'interestRatePpm': null,
                'totalFeeMinor': 0,
              });
              for (final field in [
                'productId',
                'productName',
                'customRules',
                'dayCount',
                'rounding',
                'tailDifference',
              ]) {
                row.remove(field);
              }
            }
          }
          if (table == 'installment_schedules') {
            for (final row in rows) {
              row.remove('stageId');
            }
          }
          if (table == 'repayments') {
            for (final row in rows) {
              if (schemaVersion == 29) {
                row.remove('repaymentDate');
              } else if (schemaVersion == 30 && row['id'] != 'offline') {
                row['repaymentDate'] = null;
              }
            }
          }
          add(
            table,
            '${BackupTables.sectionFor(table)}/$table.ndjson',
            rows.map(jsonEncode).join('\n'),
            rows.length,
          );
        }
        add('preferences', 'preferences.json', '{}', 0);
        final package = BackupPackage(
          manifest: BackupManifest(
            formatVersion: 1,
            appVersion: 'old',
            schemaVersion: schemaVersion,
            createdAt: DateTime(2026),
            baseCurrency: 'CNY',
            minorUnit: 2,
            backupId: 'legacy',
            files: descriptors,
          ),
          files: files,
        );
        final service = BackupService(
          gateway: gateway,
          packageStore: _PackageStore(package),
        );
        final upgraded = (await service.inspect('old')).snapshot;
        expect(
          upgraded.rows('installment_stage_configs').single['id'],
          'old:stage:1',
        );
        expect(
          upgraded.rows('installment_schedules').map((r) => r['stageId']),
          everyElement('old:stage:1'),
        );
        await service.restore('old');
        final restoredRepayments = await db.select(db.repayments).get();
        expect(
          {for (final r in restoredRepayments) r.id: r.repaymentDate},
          {
            'cash': paidAt,
            'offline': schemaVersion == 29 ? createdAt : paidAt,
            'fallback': createdAt,
          },
        );
        final restored = (await contracts.findContract('old'))!;
        expect(restored.stageTerms.stages, hasLength(1));
        expect(restored.stageTerms.repayments.single.dates.getDates(), [
          DateTime(2026, 2),
          DateTime(2026, 3),
        ]);
        expect(
          (await contracts.listSchedules(
            'old',
          )).map((s) => s.expectedPrincipal),
          loan.schedules.map((s) => s.expectedPrincipal),
        );
      },
    );
  }

  test(
    'backup rejects product values and a schedule pointing to a product stage',
    () async {
      final base = await DriftBackupGateway(db).readSnapshot();
      final snapshot = BackupSnapshot(
        tables: {
          ...base.tables,
          'installment_products': [
            {'id': 'p'},
          ],
          'installment_stage_configs': [
            {
              'id': 's',
              'ownerType': 'product',
              'ownerId': 'p',
              'position': 0,
              'stageKind': 'repayment',
              'repaymentMethod': 'interestFirst',
              'ratePpm': 1,
            },
          ],
        },
      );
      expect(
        () => BackupService.validateSnapshot(snapshot),
        throwsA(isA<BackupValidationException>()),
      );
    },
  );
}

class _PackageStore implements BackupPackageStore {
  _PackageStore(this.package);
  final BackupPackage package;
  @override
  Future<BackupPackage> read(Object source) async => package;
  @override
  Future<void> write(Object destination, BackupPackage package) async {}
}

InstallmentProduct _product({
  String name = '原产品',
  InstallmentRepaymentMethod method = InstallmentRepaymentMethod.interestFirst,
}) => InstallmentProduct(
  id: 'product',
  name: name,
  createdAt: DateTime(2026),
  stages: [
    const InstallmentStageRule.deferment(id: 'p1'),
    InstallmentStageRule.repayment(
      id: 'p2',
      method: method,
      intervalMonths: 12,
      ratePeriod: InterestRatePeriod.annual,
      accrual: InterestAccrualMethod.annual,
    ),
    const InstallmentStageRule.repayment(
      id: 'p3',
      method: InstallmentRepaymentMethod.equalInstallment,
      intervalMonths: 12,
      ratePeriod: InterestRatePeriod.annual,
      accrual: InterestAccrualMethod.annual,
      amountAlgorithm: InstallmentAmountAlgorithm.fixed,
    ),
  ],
);

InstallmentOriginationResult _loan() {
  var id = 0;
  final stages = InstallmentContractTerms(
    dayCount: DayCountConvention.thirty365,
    rounding: RoundingMode.halfEven,
    stages: [
      InstallmentContractStage(
        id: 'c1',
        terms: DefermentStage(until: DateTime(2026, 2)),
      ),
      InstallmentContractStage(
        id: 'c2',
        terms: AmortizingStage(
          method: InstallmentRepaymentMethod.interestFirst,
          dates: IntervalRepaymentDates(
            firstDate: DateTime(2027, 2),
            count: 2,
            intervalMonths: 12,
          ),
          accrual: InterestAccrualMethod.annual,
          rate: const InterestRate(
            ppm: 10000,
            period: InterestRatePeriod.annual,
          ),
        ),
      ),
      InstallmentContractStage(
        id: 'c3',
        terms: AmortizingStage(
          method: InstallmentRepaymentMethod.equalInstallment,
          dates: IntervalRepaymentDates(
            firstDate: DateTime(2029, 2),
            count: 2,
            intervalMonths: 12,
          ),
          accrual: InterestAccrualMethod.annual,
          rate: const InterestRate(
            ppm: 10000,
            period: InterestRatePeriod.annual,
          ),
          installmentAmount: const EqualInstallmentAmount.fixed(
            Money(minorUnits: 6000),
          ),
        ),
      ),
    ],
  );
  return const InstallmentOriginationService().originateDisbursement(
    contractId: 'loan',
    liabilityAccountId: 'liability',
    createdAt: DateTime(2026),
    newScheduleId: () => 's${id++}',
    terms: InstallmentOriginationTerms(
      principal: const Money(minorUnits: 10000),
      borrowingDate: DateTime(2026),
      productId: 'product',
      productName: '原产品',
      stageTerms: stages,
    ),
  );
}
