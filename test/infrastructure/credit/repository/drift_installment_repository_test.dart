import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_refund_reduction.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_change.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_repository.dart';

import '../../../helper/test_app_database.dart';

void main() {
  group('DriftInstallmentRepository', () {
    test(
      'persists default date name without changing borrowing date',
      () async {
        final database = createTestDatabase();
        addTearDown(database.close);
        final repository = DriftInstallmentRepository(database);
        final contract = _contract();
        await repository.insertAggregate(contract);
        var loaded = (await repository.findContract(contract.id))!;
        expect(loaded.name, '20260101');
        loaded.reviseDetails(name: '家庭贷款');
        await repository.saveAggregate(loaded);
        loaded = (await repository.findContract(contract.id))!;
        expect(loaded.name, '家庭贷款');
        expect(loaded.borrowingDate, DateTime(2026, 1, 1));
      },
    );
    test('maps missing aggregate save to persistence conflict', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftInstallmentRepository(database);

      await expectLater(
        () => repository.saveAggregate(_contract()),
        throwsA(
          isA<BusinessException>().having(
            (exception) => exception.code,
            'code',
            CreditErrorCode.contractPersistenceConflict.code,
          ),
        ),
      );
    });

    test('loads schedules with the contract aggregate', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftInstallmentRepository(database);
      final contract = _contract(
        id: 'aggregate-contract',
        schedules: [_schedule('aggregate-contract', 'schedule-1')],
      );

      await repository.insertAggregate(contract);
      final loaded = (await repository.findContract(contract.id))!;

      expect(loaded.schedules, hasLength(1));
      expect(loaded.schedules.single.id, 'schedule-1');
      expect(loaded.schedules.single.contractId, loaded.id);
    });

    test(
      'rolls back contract and schedules when aggregate save fails',
      () async {
        final database = createTestDatabase();
        addTearDown(database.close);
        final repository = DriftInstallmentRepository(database);
        final target = _contract(
          id: 'target',
          schedules: [_schedule('target', 'original-schedule')],
        );
        final other = _contract(
          id: 'other',
          schedules: [_schedule('other', 'colliding-schedule')],
        );
        await repository.insertAggregate(target);
        await repository.insertAggregate(other);
        final loaded = (await repository.findContract(target.id))!;
        loaded.reviseDetails(name: 'changed');
        final changedTerms = InstallmentContractTerms.singleStage(
          id: 'target:stage:1',
          totalPeriods: 2,
          firstDate: DateTime(2026, 2, 1),
          lastDate: DateTime(2026, 3, 1),
          method: InstallmentRepaymentMethod.equalPrincipal,
          accrual: InterestAccrualMethod.monthly,
          feeMinor: 100,
        );
        loaded.applyPlanChange(
          InstallmentPlanChangeSet(
            context: InstallmentPlanContext.fromContract(contract: loaded),
            terms: changedTerms,
            rows: [
              InstallmentPlanRow(
                id: null,
                stageId: 'target:stage:1',
                periodNo: 1,
                date: DateTime(2026, 2, 1),
                principal: const Money(minorUnits: 1000),
                interest: Money.zero(),
                fee: Money.zero(),
                status: InstallmentScheduleStatus.pending,
              ),
            ],
          ),
          newId: () => 'colliding-schedule',
          createdAt: DateTime(2026, 1, 2),
        );

        await expectLater(
          repository.saveAggregate(loaded),
          throwsA(isA<Exception>()),
        );

        final restored = (await repository.findContract(target.id))!;
        expect(restored.name, '20260101');
        expect(restored.stageTerms.totalFeeMinor, 0);
        expect(restored.schedules.single.id, 'original-schedule');
        expect(
          restored.schedules.single.expectedPrincipal,
          const Money(minorUnits: 1000),
        );
      },
    );

    test('persists purchase source and transaction reference', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftInstallmentRepository(database);
      final contract = InstallmentContract(
        id: 'purchase-contract',
        liabilityAccountId: 'credit-card',
        installmentType: InstallmentType.purchase,
        sourceRefId: 'purchase-transaction',
        principal: const Money(minorUnits: 120000),
        borrowingDate: DateTime(2026, 1, 1),
        status: InstallmentContractStatus.active,
        createdAt: DateTime(2026, 1, 1),
        stageTerms: InstallmentContractTerms.singleStage(
          id: 'purchase-contract:stage:1',
          totalPeriods: 12,
          firstDate: DateTime(2026, 2, 1),
          method: InstallmentRepaymentMethod.equalPrincipal,
          accrual: InterestAccrualMethod.monthly,
          feeMinor: 0,
        ),
      );

      await repository.insertAggregate(contract);
      final loaded = (await repository.findContract(contract.id))!;

      expect(loaded.installmentType, InstallmentType.purchase);
      expect(loaded.sourceRefId, 'purchase-transaction');
    });

    test('rejects a second contract for the same typed source fact', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftInstallmentRepository(database);

      await repository.insertAggregate(
        _purchaseContract('first', 'shared-source'),
      );
      await expectLater(
        repository.insertAggregate(
          _purchaseContract('second', 'shared-source'),
        ),
        throwsA(anything),
      );
    });

    test('reads refund reductions with the refund business time', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftInstallmentRepository(database);
      final contract = InstallmentContract(
        id: 'purchase-contract',
        liabilityAccountId: 'credit-card',
        installmentType: InstallmentType.purchase,
        sourceRefId: 'purchase-transaction',
        principal: const Money(minorUnits: 120000),
        borrowingDate: DateTime(2026, 1, 1),
        status: InstallmentContractStatus.active,
        createdAt: DateTime(2026, 1, 1),
        stageTerms: InstallmentContractTerms.singleStage(
          id: 'purchase-contract:stage:1',
          totalPeriods: 12,
          firstDate: DateTime(2026, 2, 1),
          method: InstallmentRepaymentMethod.equalPrincipal,
          accrual: InterestAccrualMethod.monthly,
          feeMinor: 0,
        ),
      );
      await repository.insertAggregate(contract);
      await database
          .into(database.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: 'refund',
              businessPurpose: BusinessPurpose.refund,
              occurredAt: DateTime(2026, 3, 8, 10),
              postedAt: DateTime(2026, 3, 9),
              primaryAmountMinor: 60000,
              sourceKind: SourceKind.manual,
            ),
          );
      await repository.save(
        InstallmentRefundReduction(
          id: 'reduction',
          contractId: contract.id,
          refundTransactionId: 'refund',
          principal: const Money(minorUnits: 60000),
          occurredAt: DateTime(2026, 3, 8, 10),
          createdAt: DateTime(2026, 3, 8, 10),
        ),
      );

      final reductions = await repository.listByContract(contract.id);

      expect(reductions.single.principal, const Money(minorUnits: 60000));
      expect(reductions.single.occurredAt, DateTime(2026, 3, 8, 10));
    });
  });
}

InstallmentContract _contract({
  String id = 'missing-contract',
  List<InstallmentSchedule> schedules = const [],
}) {
  return InstallmentContract(
    id: id,
    liabilityAccountId: 'liability',
    installmentType: InstallmentType.disbursement,
    principal: const Money(minorUnits: 1000),
    borrowingDate: DateTime(2026, 1, 1),
    status: InstallmentContractStatus.active,
    createdAt: DateTime(2026, 1, 1),
    schedules: schedules,
    stageTerms: InstallmentContractTerms.singleStage(
      id: '$id:stage:1',
      totalPeriods: 2,
      firstDate: DateTime(2026, 2, 1),
      lastDate: DateTime(2026, 3, 1),
      method: InstallmentRepaymentMethod.equalPrincipal,
      accrual: InterestAccrualMethod.monthly,
      feeMinor: 0,
    ),
  );
}

InstallmentSchedule _schedule(String contractId, String id) {
  return InstallmentSchedule(
    id: id,
    contractId: contractId,
    periodNo: 1,
    expectedRepaymentDate: DateTime(2026, 2, 1),
    expectedPrincipal: const Money(minorUnits: 1000),
    expectedInterest: Money.zero(),
    expectedFee: Money.zero(),
    status: InstallmentScheduleStatus.pending,
    createdAt: DateTime(2026, 1, 1),
  );
}

InstallmentContract _purchaseContract(String id, String sourceRefId) {
  return InstallmentContract(
    id: id,
    liabilityAccountId: 'credit-card',
    installmentType: InstallmentType.purchase,
    sourceRefId: sourceRefId,
    principal: const Money(minorUnits: 120000),
    borrowingDate: DateTime(2026, 1, 1),
    status: InstallmentContractStatus.active,
    createdAt: DateTime(2026, 1, 1),
    stageTerms: InstallmentContractTerms.singleStage(
      id: '$id:stage:1',
      totalPeriods: 1,
      firstDate: DateTime(2026, 2, 1),
      method: InstallmentRepaymentMethod.equalPrincipal,
      accrual: InterestAccrualMethod.monthly,
      feeMinor: 0,
    ),
  );
}
