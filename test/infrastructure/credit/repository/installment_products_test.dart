import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/product/installment_product_app_service.dart';
import 'package:smartflow/application/data_management/backup/backup_models.dart';
import 'package:smartflow/application/data_management/backup/backup_service.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/money/rounding_mode.dart';
import 'package:smartflow/domain/credit/entity/installment_product.dart';
import 'package:smartflow/domain/credit/service/installment/installment_contract_origination_service.dart';
import 'package:smartflow/domain/credit/service/installment/installment_plan_engine.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_operation.dart';
import 'package:smartflow/domain/credit/valobj/day_count_convention.dart';
import 'package:smartflow/domain/credit/valobj/equal_installment_amount.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_terms.dart';
import 'package:smartflow/domain/credit/valobj/installment_stage_rule.dart';
import 'package:smartflow/domain/credit/valobj/interest_rate.dart';
import 'package:smartflow/domain/credit/valobj/repayment_dates_strategy.dart';
import 'package:smartflow/domain/credit/valobj/reference_rate.dart';
import 'package:smartflow/domain/credit/valobj/in_period_repricing_policy.dart';
import 'package:smartflow/domain/credit/valobj/tail_difference_policy.dart';
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
    'product service round-trips benchmark rules and stage policies',
    () async {
      final service = InstallmentProductAppServiceImpl(
        repository: products,
        runner: DriftTransactionRunner(db),
        ids: SequentialIdGenerator(),
      );
      final id = await service.save(
        name: '浮动利率模板',
        dayCount: DayCountConvention.thirty365,
        rounding: RoundingMode.halfEven,
        stages: const [
          InstallmentStageRule.repayment(
            id: 'draft',
            method: InstallmentRepaymentMethod.equalInstallment,
            intervalMonths: 1,
            ratePeriod: InterestRatePeriod.annual,
            accrual: InterestAccrualMethod.daily,
            amountAlgorithm: InstallmentAmountAlgorithm.actualRate,
            rateType: InterestRateType.loanBenchmarkLongTerm,
            repricingCycleMonths: 6,
            inPeriodRepricingPolicy: InPeriodRepricingPolicy.dynamicPeriodRate,
            tailDifference: TailDifferencePolicy.lastPeriod,
          ),
        ],
      );
      final product = (await products.find(id))!;
      final rule = product.stages.single;
      expect(rule.rateType, InterestRateType.loanBenchmarkLongTerm);
      expect(rule.repricingCycleMonths, 6);
      expect(
        rule.inPeriodRepricingPolicy,
        InPeriodRepricingPolicy.dynamicPeriodRate,
      );
      expect(rule.tailDifference, TailDifferencePolicy.lastPeriod);
      expect(rule.amountAlgorithm, InstallmentAmountAlgorithm.actualRate);
      final row = await (db.select(
        db.installmentProductStageConfigs,
      )..where((row) => row.productId.equals(id))).getSingle();
      expect(row.rateType, 'loanBenchmarkLongTerm');
      expect(row.repricingCycleMonths, 6);
      expect(await db.select(db.installmentStageConfigs).get(), isEmpty);
    },
  );

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
      await db.customStatement("DELETE FROM installment_stage_configs");
      await expectLater(
        contracts.findContract('loan'),
        throwsA(isA<BusinessException>()),
      );
    },
  );

  test(
    'product rows contain only stable rules and enforce absence of variable data',
    () async {
      await products.save(_product());
      final rows = await (db.select(
        db.installmentProductStageConfigs,
      )..where((s) => s.productId.equals('product'))).get();
      expect(rows, hasLength(3));
      final columns =
          (await db
                  .customSelect(
                    'PRAGMA table_info(installment_product_stage_configs)',
                  )
                  .get())
              .map((row) => row.read<String>('name'))
              .toSet();
      expect(
        columns.intersection({
          'periods',
          'initial_rate_ppm',
          'spread_bp',
          'end_date',
          'fixed_amount_minor',
          'fee_minor',
        }),
        isEmpty,
      );
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
            "UPDATE installment_product_stage_configs SET $field = 1 WHERE id = 'p2'",
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
      loan.contract.reviseDetails(name: '保留的合同名称');
      await contracts.insertAggregate(loan.contract, loan.schedules);
      await products.save(
        _product(
          name: '新版产品',
          method: InstallmentRepaymentMethod.equalPrincipal,
        ),
      );
      final loaded = (await contracts.findContract('loan'))!;
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
      final before = const InstallmentPlanEngine()
          .generate(
            loaded.stageTerms.planTerms(loaded.principal, loaded.borrowingDate),
            operations: InstallmentPlanOperations(
              principalReductions: [
                PrincipalReduction(
                  date: loaded.borrowingDate,
                  principal: const Money(minorUnits: 1000),
                ),
              ],
            ),
          )
          .entries;
      final gateway = DriftBackupGateway(db);
      final snapshot = await gateway.readSnapshot();
      await gateway.replaceSnapshot(snapshot);
      final restored = (await contracts.findContract('loan'))!;
      final after = const InstallmentPlanEngine()
          .generate(
            restored.stageTerms.planTerms(
              restored.principal,
              restored.borrowingDate,
            ),
            operations: InstallmentPlanOperations(
              principalReductions: [
                PrincipalReduction(
                  date: restored.borrowingDate,
                  principal: const Money(minorUnits: 1000),
                ),
              ],
            ),
          )
          .entries;
      expect(
        after.map((r) => r.expectedPrincipal),
        before.map((r) => r.expectedPrincipal),
      );
      expect(
        after.map((r) => r.expectedInterest),
        before.map((r) => r.expectedInterest),
      );
      expect(restored.name, '保留的合同名称');
    },
  );

  test(
    'product deletion preserves existing contracts and invalid save is atomic',
    () async {
      await products.save(_product());
      final loan = _loan();
      await contracts.insertAggregate(loan.contract, loan.schedules);
      final service = InstallmentProductAppServiceImpl(
        repository: products,
        runner: DriftTransactionRunner(db),
        ids: SequentialIdGenerator(prefix: 'p'),
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
      await service.delete('product');
      expect(await products.find('product'), isNull);
      expect(await contracts.findContract('loan'), isNotNull);
      expect(await contracts.listSchedules('loan'), hasLength(4));
      expect(
        await (db.select(
          db.installmentProductStageConfigs,
        )..where((s) => s.productId.equals('product'))).get(),
        isEmpty,
      );
      await contracts.deleteContract('loan');
      expect(await db.select(db.installmentStageConfigs).get(), isEmpty);
    },
  );

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
  return const InstallmentContractOriginationService().originateDisbursement(
    contractId: 'loan',
    liabilityAccountId: 'liability',
    createdAt: DateTime(2026),
    newScheduleId: () => 's${id++}',
    terms: InstallmentOriginationTerms(
      principal: const Money(minorUnits: 10000),
      borrowingDate: DateTime(2026),
      stageTerms: stages,
    ),
  );
}
