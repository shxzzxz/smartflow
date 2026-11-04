import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/transaction_view/business_activity_item/source/installment_business_activity_item_source.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';

class _MockInstallmentQueryService extends Mock
    implements InstallmentQueryService {}

void main() {
  test('maps credit-owned installment fact kinds', () async {
    final query = _MockInstallmentQueryService();
    final transaction = _transaction(BusinessPurpose.refund);
    final installment = InstallmentDTO(
      id: 'contract-1',
      name: '消费分期',
      liabilityAccountId: 'credit',
      installmentType: InstallmentType.purchase,
      sourceRefId: 'tx-1',
      principal: const Money(minorUnits: 1200),
      borrowingDate: DateTime(2026, 1, 1),
      status: InstallmentContractStatus.active,
      createdAt: DateTime(2026, 1, 1),
      stageTerms: InstallmentContractTerms.singleStage(
        totalPeriods: 1,
        firstDate: DateTime(2026, 2, 1),
        method: InstallmentRepaymentMethod.equalInstallment,
        accrual: InterestAccrualMethod.monthly,
      ),
      repaymentProgress: const InstallmentRepaymentProgressDTO(
        paidPeriodCount: 0,
        totalPeriodCount: 1,
        remainingPrincipal: Money(minorUnits: 1200),
        repaid: RepaymentAmountBreakdown.zero,
      ),
    );
    when(
      () => query.findInstallments({'contract-1'}),
    ).thenAnswer((_) async => {'contract-1': installment});
    final source = InstallmentBusinessActivityItemSource(query);

    final item =
        (await source.findItems([transaction]))['tx-1']
            as InstallmentBusinessActivityItem;

    expect(item.factKind, InstallmentTransactionFactKind.refund);
    expect(item.installmentType, InstallmentType.purchase);
  });
}

TransactionReadModel _transaction(BusinessPurpose purpose) {
  return TransactionReadModel(
    id: 'tx-1',
    businessPurpose: purpose,
    occurredAt: DateTime(2026, 1, 15),
    primaryAmount: const Money(minorUnits: 1200),
    ownership: const TransactionOwnership(
      ownerType: installmentOwnerType,
      ownerId: 'contract-1',
    ),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
  );
}
