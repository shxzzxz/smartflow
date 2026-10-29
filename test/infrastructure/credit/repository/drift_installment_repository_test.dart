import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_refund_reduction.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
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
        await repository.insertAggregate(contract, []);
        var loaded = (await repository.findContract(contract.id))!;
        expect(loaded.name, '20260101');
        loaded.reviseDetails(name: '家庭贷款');
        await repository.saveAggregate(loaded, []);
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
        () => repository.saveAggregate(_contract(), const []),
        throwsA(
          isA<BusinessException>().having(
            (exception) => exception.code,
            'code',
            CreditErrorCode.contractPersistenceConflict.code,
          ),
        ),
      );
    });

    test('persists purchase source and transaction reference', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftInstallmentRepository(database);
      final contract = InstallmentContract(
        id: 'purchase-contract',
        liabilityAccountId: 'credit-card',
        sourceType: InstallmentSourceType.purchase,
        purchaseTransactionId: 'purchase-transaction',
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

      await repository.insertAggregate(contract, const []);
      final loaded = (await repository.findContract(contract.id))!;

      expect(loaded.sourceType, InstallmentSourceType.purchase);
      expect(loaded.purchaseTransactionId, 'purchase-transaction');
    });

    test('reads refund reductions with the refund business time', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftInstallmentRepository(database);
      final contract = InstallmentContract(
        id: 'purchase-contract',
        liabilityAccountId: 'credit-card',
        sourceType: InstallmentSourceType.purchase,
        purchaseTransactionId: 'purchase-transaction',
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
      await repository.insertAggregate(contract, const []);
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

InstallmentContract _contract() {
  return InstallmentContract(
    id: 'missing-contract',
    liabilityAccountId: 'liability',
    sourceType: InstallmentSourceType.disbursement,
    principal: const Money(minorUnits: 1000),
    borrowingDate: DateTime(2026, 1, 1),
    status: InstallmentContractStatus.active,
    createdAt: DateTime(2026, 1, 1),
    stageTerms: InstallmentContractTerms.singleStage(
      id: 'missing-contract:stage:1',
      totalPeriods: 2,
      firstDate: DateTime(2026, 2, 1),
      lastDate: DateTime(2026, 3, 1),
      method: InstallmentRepaymentMethod.equalPrincipal,
      accrual: InterestAccrualMethod.monthly,
      feeMinor: 0,
    ),
  );
}
