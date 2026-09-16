import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/installment/command/installment_plan_app_service.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/domain/credit/service/installment/installment_contract_origination_service.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_change.dart';
import 'package:smartflow/domain/credit/valobj/repayment_amount_breakdown.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_bill_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_repayment_repository.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import '../../helper/test_app_database.dart';
import '../../helper/sequential_id_generator.dart';

void main() {
  late AppDatabase db;
  late DriftInstallmentRepository installments;
  late DriftRepaymentRepository repayments;
  late InstallmentPlanAppService service;
  final date = DateTime(2026, 1, 15);
  setUp(() async {
    db = createTestDatabase();
    installments = DriftInstallmentRepository(db);
    repayments = DriftRepaymentRepository(db);
    final ids = SequentialIdGenerator();
    service = InstallmentPlanAppService(
      installments: installments,
      repayments: repayments,
      bills: DriftBillRepository(db),
      runner: DriftTransactionRunner(db),
      idGenerator: ids,
    );
    final aggregate = const InstallmentContractOriginationService()
        .originateDisbursement(
          contractId: 'loan',
          liabilityAccountId: 'account',
          createdAt: DateTime(2026),
          newScheduleId: ids.newId,
          terms: InstallmentOriginationTerms(
            principal: const Money(minorUnits: 12000),
            borrowingDate: DateTime(2026),
            stageTerms: _terms(),
          ),
        );
    await installments.insertAggregate(aggregate.contract, aggregate.schedules);
  });
  tearDown(() => db.close());

  Future<void> prepay(int principal) => repayments.saveRepayment(
    Repayment(
      id: 'prepay',
      repaymentType: RepaymentType.prepayment,
      targetType: RepaymentTargetType.contract,
      targetId: 'loan',
      repaymentDate: date,
      items: [
        RepaymentItem(
          id: 'item',
          repaymentId: 'prepay',
          allocated: RepaymentAmountBreakdown(
            principal: Money(minorUnits: principal),
            interest: Money.zero(),
            fee: Money.zero(),
            discount: Money.zero(),
          ),
        ),
      ],
    ),
  );

  for (final mutation in [
    'amount',
    'status',
    'prepayment',
    'terms',
    'request',
  ]) {
    test(
      'confirmation rejects changed $mutation facts without overwriting them',
      () async {
        final request = RecalculateFromTerms(_terms());
        final preview = await service.previewChange('loan', request);
        final contract = (await installments.findContract('loan'))!;
        final rows = await installments.listSchedules('loan');
        switch (mutation) {
          case 'amount':
            rows.first.reviseExpectation(
              expectedInterest: const Money(minorUnits: 99),
            );
          case 'status':
            rows.first.markPaid();
          case 'terms':
            contract.reviseStageTerms(_terms(fee: 60));
          case 'prepayment':
            await prepay(3000);
          case 'request':
            break;
        }
        await installments.saveAggregate(contract, rows);
        await expectLater(
          service.confirmChange(
            'loan',
            mutation == 'request'
                ? RecalculateFromTerms(_terms(fee: 90))
                : request,
            token: preview.token,
          ),
          throwsA(
            isA<BusinessException>().having(
              (e) => e.code,
              'code',
              'credit.contract.persistence_conflict',
            ),
          ),
        );
        final after = await installments.listSchedules('loan');
        expect(
          after.map((r) => r.expectedPrincipal),
          rows.map((r) => r.expectedPrincipal),
        );
        expect(
          after.map((r) => r.expectedInterest),
          rows.map((r) => r.expectedInterest),
        );
        expect(after.map((r) => r.status), rows.map((r) => r.status));
      },
    );
  }

  test(
    'unrelated name edit preserves preview and new identities are allocated only on apply',
    () async {
      final request = RecalculateFromTerms(_terms(count: 4));
      final before = await installments.listSchedules('loan');
      final preview = await service.previewChange('loan', request);
      final second = await service.previewChange('loan', request);
      expect(second.token, preview.token);
      expect(preview.change.rows.where((row) => row.id == null), hasLength(1));
      expect(await installments.listSchedules('loan'), hasLength(3));
      final contract = (await installments.findContract('loan'))!
        ..reviseDetails(name: '新名称');
      await installments.saveAggregate(contract, before);
      await service.confirmChange('loan', request, token: preview.token);
      final saved = await installments.listSchedules('loan');
      expect(saved.take(3).map((r) => r.id), before.map((r) => r.id));
      expect(saved.map((r) => r.id).toSet(), hasLength(4));
      expect(saved.map((r) => r.expectedPrincipal.minorUnits), [
        3000,
        3000,
        3000,
        3000,
      ]);
      expect((await installments.findContract('loan'))!.name, '新名称');
    },
  );

  test(
    'prepayment and deletion recompute without adding manual-adjustment flags',
    () async {
      final before = await installments.listSchedules('loan');
      await prepay(3000);
      await service.applyAutomaticChange(
        'loan',
        const RecalculateFromOperations(),
      );
      var rows = await installments.listSchedules('loan');
      expect(rows.map((r) => r.expectedPrincipal.minorUnits), [
        3000,
        3000,
        3000,
      ]);
      expect(rows.every((r) => !r.manuallyAdjusted), isTrue);
      expect(rows.map((r) => r.id), before.map((r) => r.id));
      await repayments.deleteRepayment('prepay');
      await service.applyAutomaticChange(
        'loan',
        const RecalculateFromOperations(),
      );
      rows = await installments.listSchedules('loan');
      expect(rows.map((r) => r.expectedPrincipal.minorUnits), [
        4000,
        4000,
        4000,
      ]);
      expect(rows.every((r) => !r.manuallyAdjusted), isTrue);
    },
  );

  test(
    'failure after plan write rolls back plan and prepayment together',
    () async {
      final before = await installments.listSchedules('loan');
      await expectLater(
        DriftTransactionRunner(db).run(() async {
          await prepay(3000);
          await service.applyAutomaticChange(
            'loan',
            const RecalculateFromOperations(),
          );
          expect(
            (await installments.listSchedules(
              'loan',
            )).first.expectedPrincipal.minorUnits,
            3000,
          );
          throw StateError('failure after plan write');
        }),
        throwsStateError,
      );
      expect(await repayments.findRepayment('prepay'), isNull);
      final after = await installments.listSchedules('loan');
      expect(
        after.map((r) => r.expectedPrincipal),
        before.map((r) => r.expectedPrincipal),
      );
    },
  );

  test(
    'terms rebuild replaces manual expectations across all statuses and repairs states',
    () async {
      final contract = (await installments.findContract('loan'))!;
      final rows = await installments.listSchedules('loan');
      rows.first.manuallyAdjusted = true;
      rows.first.markPaid();
      rows.last.manuallyAdjusted = true;
      rows.last.reviseExpectation(
        expectedInterest: const Money(minorUnits: 99),
      );
      await installments.saveAggregate(contract, rows);
      final request = RecalculateFromTerms(_terms());
      await expectLater(
        service.applyAutomaticChange('loan', request),
        throwsA(isA<BusinessException>()),
      );
      final preview = await service.previewChange('loan', request);
      await service.confirmChange('loan', request, token: preview.token);
      final after = await installments.listSchedules('loan');
      expect(after.first.manuallyAdjusted, isFalse);
      expect(after.first.status, InstallmentScheduleStatus.pending);
      expect(after.last.manuallyAdjusted, isFalse);
      expect(after.last.expectedInterest, Money.zero());
    },
  );
}

InstallmentContractTerms _terms({int count = 3, int fee = 0}) =>
    InstallmentContractTerms.singleStage(
      id: 'stage',
      totalPeriods: count,
      firstDate: DateTime(2026, 2, 1),
      method: InstallmentRepaymentMethod.equalPrincipal,
      accrual: InterestAccrualMethod.monthly,
      feeMinor: fee,
    );
