import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/application/credit/installment/command/installment_app_service.dart';
import 'package:smartflow/application/credit/installment/command/installment_command.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/installment_product.dart';
import 'package:smartflow/domain/credit/entity/installment_repricing.dart';
import 'package:smartflow/domain/credit/port/installment_product_repository.dart';
import 'package:smartflow/domain/credit/valobj/floating_rate.dart';
import 'package:smartflow/domain/credit/valobj/reference_rate.dart';
import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_terms.dart';
import 'package:smartflow/domain/credit/valobj/installment_stage_rule.dart';
import 'package:smartflow/domain/credit/valobj/interest_rate.dart';
import 'package:smartflow/domain/credit/valobj/repayment_dates_strategy.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_product_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_repricing_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_bill_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_repayment_repository.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import '../../helper/test_app_database.dart';
import '../../helper/sequential_id_generator.dart';

class _Ledger extends Mock implements CreditLedgerPort {}

class _Products extends Mock implements InstallmentProductRepository {}

void main() {
  late AppDatabase db;
  late DriftInstallmentRepository repository;
  late DriftInstallmentProductRepository products;
  late InstallmentAppService service;
  setUp(() async {
    db = createTestDatabase();
    repository = DriftInstallmentRepository(db);
    products = DriftInstallmentProductRepository(db);
    service = InstallmentAppServiceImpl(
      repository: repository,
      products: products,
      bills: DriftBillRepository(db),
      repayments: DriftRepaymentRepository(db),
      ledger: _Ledger(),
      transactionRunner: DriftTransactionRunner(db),
      idGenerator: SequentialIdGenerator(),
    );
    await products.save(
      InstallmentProduct(
        id: 'p',
        name: '先息后本',
        createdAt: DateTime(2026),
        stages: [
          const InstallmentStageRule.repayment(
            id: 'p-stage',
            method: InstallmentRepaymentMethod.interestFirst,
            intervalMonths: 1,
            ratePeriod: InterestRatePeriod.annual,
            accrual: InterestAccrualMethod.monthly,
          ),
        ],
      ),
    );
  });
  tearDown(() => db.close());

  for (final rejectProduct in [false, true]) {
    test(
      rejectProduct
          ? 'failed contract edit restores the written plan and discarded repricing candidate'
          : 'contract edit commits rebuilt plan, details and candidate cleanup together',
      () async {
        final rule = FloatingRateRule(
          referenceRateType: ReferenceRateType.lprFiveYearPlus,
          spreadBp: 0,
          firstResetDate: DateTime(2026, 1, 10),
          firstEffectiveDate: DateTime(2026, 1, 15),
        );
        final created = await service.createDisbursementContract(
          _command(10000, 12000, floatingRate: rule),
        );
        final original = (await repository.findContract(created.contractId))!;
        final before = await repository.listSchedules(original.id);
        final records = DriftInstallmentRepricingRepository(db);
        await records.insert(
          InstallmentRepricing(
            id: 'pending-reset',
            contractId: original.id,
            stageId: original.stageTerms.stages.single.id,
            change: RateChange(
              resetDate: rule.firstResetDate,
              effectiveDate: rule.firstEffectiveDate,
              referenceRate: ReferenceRate(
                type: rule.referenceRateType,
                date: DateTime(2026, 1, 1),
                ratePpm: 15000,
                source: 'test',
              ),
              spreadBp: 0,
            ),
          ),
        );
        final terms = InstallmentContractTerms(
          stages: [
            InstallmentContractStage(
              id: original.stageTerms.stages.single.id,
              terms: AmortizingStage(
                dates: original.stageTerms.repayments.single.dates,
                method: InstallmentRepaymentMethod.interestFirst,
                rate: const InterestRate(
                  ppm: 24000,
                  period: InterestRatePeriod.annual,
                ),
                floatingRate: rule,
              ),
            ),
          ],
        );
        final rejectedProducts = _Products();
        when(() => rejectedProducts.find('missing-product')).thenAnswer((
          _,
        ) async {
          // 后续产品校验失败前，重算和候选清理已经实际写入数据库。
          expect(
            (await repository.findContract(
              original.id,
            ))!.stageTerms.repayments.single.rate!.ppm,
            24000,
          );
          expect(
            (await repository.listSchedules(
              original.id,
            )).first.expectedInterest,
            isNot(before.first.expectedInterest),
          );
          expect(await records.list(original.id), isEmpty);
          return null;
        });
        final editing = InstallmentAppServiceImpl(
          repository: repository,
          products: rejectProduct ? rejectedProducts : products,
          repricings: records,
          bills: DriftBillRepository(db),
          repayments: DriftRepaymentRepository(db),
          ledger: _Ledger(),
          transactionRunner: DriftTransactionRunner(db),
          idGenerator: SequentialIdGenerator(),
        );
        final preview = await editing.previewContractRecalculation(
          PreviewContractRecalculationCommand(
            contractId: original.id,
            stageTerms: terms,
          ),
        );
        final command = UpdateContractCommand(
          contractId: original.id,
          name: 'Updated loan',
          productId: rejectProduct ? 'missing-product' : null,
          stageTerms: terms,
          regeneratePlan: true,
          planPreviewToken: preview.token,
        );

        if (rejectProduct) {
          await expectLater(
            editing.updateContract(command),
            throwsA(isA<BusinessException>()),
          );
          verify(() => rejectedProducts.find('missing-product')).called(1);
        } else {
          await editing.updateContract(command);
        }

        final saved = (await repository.findContract(original.id))!;
        final rows = await repository.listSchedules(original.id);
        expect(saved.name, rejectProduct ? original.name : 'Updated loan');
        expect(
          saved.stageTerms.repayments.single.rate!.ppm,
          rejectProduct ? 12000 : 24000,
        );
        expect(rows.map((r) => r.id), before.map((r) => r.id));
        expect(
          rows.map((r) => r.expectedInterest),
          rejectProduct
              ? before.map((r) => r.expectedInterest)
              : preview.schedules.map((r) => r.expectedInterest),
        );
        expect(
          (await records.list(original.id)).map((r) => r.id),
          rejectProduct ? ['pending-reset'] : isEmpty,
        );
      },
    );
  }

  test(
    'contract name and selected template persist independently of schedule edits',
    () async {
      final created = await service.createDisbursementContract(
        _command(10000, 12000),
      );
      final contract = (await repository.findContract(created.contractId))!;
      expect(contract.name, '20260101');
      final before = await repository.listSchedules(contract.id);
      await service.updateContract(
        UpdateContractCommand(
          contractId: contract.id,
          name: '家庭贷款',
          productId: 'builtin-loan-interest-first',
          stageTerms: contract.stageTerms,
          customRules: true,
        ),
      );
      final saved = (await repository.findContract(contract.id))!;
      expect(saved.name, '家庭贷款');
      expect(saved.productId, 'builtin-loan-interest-first');
      expect(saved.productName, '先息后本');
      expect(
        (await repository.listSchedules(
          contract.id,
        )).map((s) => s.expectedPrincipal),
        before.map((s) => s.expectedPrincipal),
      );
      await expectLater(
        service.updateContract(
          UpdateContractCommand(contractId: contract.id, name: ' '),
        ),
        throwsA(isA<BusinessException>()),
      );
      expect((await repository.findContract(contract.id))!.name, '家庭贷款');
    },
  );

  test(
    'two loans from a product own separate rows and different actual terms',
    () async {
      final first = await service.createDisbursementContract(
        _command(10000, 12000),
      );
      final second = await service.createDisbursementContract(
        _command(20000, 24000),
      );
      final a = (await repository.findContract(first.contractId))!;
      final b = (await repository.findContract(second.contractId))!;
      expect(a.productId, 'p');
      expect(a.productName, '先息后本');
      expect(
        a.stageTerms.stages.single.id,
        isNot(b.stageTerms.stages.single.id),
      );
      expect(a.stageTerms.stages.single.id, isNot('p-stage'));
      expect(a.stageTerms.repayments.single.rate!.ppm, 12000);
      expect(b.stageTerms.repayments.single.rate!.ppm, 24000);
      expect(
        (await repository.listSchedules(
          b.id,
        )).last.expectedPrincipal.minorUnits,
        20000,
      );
      expect((await products.find('p'))!.stages.single.id, 'p-stage');
    },
  );

  test(
    'preview is read only and explicit stage rebuild preserves existing identities',
    () async {
      final created = await service.createDisbursementContract(
        _command(10000, 12000),
      );
      final original = (await repository.findContract(created.contractId))!;
      final existing = await repository.listSchedules(original.id);
      final changed = InstallmentContractTerms(
        stages: [
          InstallmentContractStage(
            id: original.stageTerms.stages.single.id,
            terms: AmortizingStage(
              method: InstallmentRepaymentMethod.interestFirst,
              dates: IntervalRepaymentDates(
                firstDate: DateTime(2026, 2),
                count: 2,
              ),
              rate: const InterestRate(
                ppm: 12000,
                period: InterestRatePeriod.annual,
              ),
            ),
          ),
          InstallmentContractStage(
            id: 'new-stage',
            terms: AmortizingStage(
              method: InstallmentRepaymentMethod.equalPrincipal,
              dates: IntervalRepaymentDates(
                firstDate: DateTime(2026, 4),
                count: 2,
              ),
            ),
          ),
        ],
      );
      final preview = await service.previewContractRecalculation(
        PreviewContractRecalculationCommand(
          contractId: original.id,
          stageTerms: changed,
        ),
      );
      expect(preview.schedules, hasLength(4));
      expect(
        (await repository.findContract(original.id))!.stageTerms.stages,
        hasLength(1),
      );
      expect((await repository.listSchedules(original.id)), hasLength(2));
      await expectLater(
        service.updateContract(
          UpdateContractCommand(contractId: original.id, stageTerms: changed),
        ),
        throwsA(isA<BusinessException>()),
      );
      await service.updateContract(
        UpdateContractCommand(
          contractId: original.id,
          stageTerms: changed,
          customRules: true,
          regeneratePlan: true,
          planPreviewToken: preview.token,
        ),
      );
      final rows = await repository.listSchedules(original.id);
      expect(rows.map((r) => r.periodNo), [1, 2, 3, 4]);
      expect(rows.take(2).map((r) => r.id), existing.map((r) => r.id));
      expect(rows.take(2).map((r) => r.expectedPrincipal.minorUnits), [0, 0]);
      expect(rows.skip(2).map((r) => r.expectedPrincipal.minorUnits), [
        5000,
        5000,
      ]);
      expect((await repository.findContract(original.id))!.customRules, isTrue);
    },
  );

  test(
    'stage edits cannot move frozen schedules and failure rolls back all rows',
    () async {
      final created = await service.createDisbursementContract(
        _command(10000, 12000),
      );
      final original = (await repository.findContract(created.contractId))!;
      final rows = await repository.listSchedules(original.id);
      rows.first.markPaid();
      await repository.saveAggregate(original, rows);
      final changed = InstallmentContractTerms(
        stages: [
          InstallmentContractStage(
            id: 'replacement',
            terms: original.stageTerms.stages.single.terms,
          ),
        ],
      );
      await expectLater(
        service.previewContractRecalculation(
          PreviewContractRecalculationCommand(
            contractId: original.id,
            stageTerms: changed,
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
      await expectLater(
        service.updateContract(
          UpdateContractCommand(
            contractId: original.id,
            stageTerms: changed,
            regeneratePlan: true,
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
      final after = await repository.listSchedules(original.id);
      expect(after.first.id, rows.first.id);
      expect(after.first.status, InstallmentScheduleStatus.paid);
      expect(
        (await repository.findContract(
          original.id,
        ))!.stageTerms.stages.single.id,
        original.stageTerms.stages.single.id,
      );
    },
  );
}

CreateDisbursementContractCommand _command(
  int principal,
  int rate, {
  FloatingRateRule? floatingRate,
}) => CreateDisbursementContractCommand(
  liabilityAccountId: 'loan-account',
  principal: Money(minorUnits: principal),
  borrowingDate: DateTime(2026),
  productId: 'p',
  stageTerms: InstallmentContractTerms(
    stages: [
      InstallmentContractStage(
        id: 'p-stage',
        terms: AmortizingStage(
          method: InstallmentRepaymentMethod.interestFirst,
          dates: IntervalRepaymentDates(firstDate: DateTime(2026, 2), count: 2),
          rate: InterestRate(ppm: rate, period: InterestRatePeriod.annual),
          floatingRate: floatingRate,
        ),
      ),
    ],
  ),
);
