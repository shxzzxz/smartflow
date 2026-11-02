part of 'transaction_detail_view_model.dart';

final class _AdvanceActionDispatcher
    implements _TransactionDetailActionDispatcher {
  const _AdvanceActionDispatcher({
    required this.transaction,
    required this.owner,
    required this.advanceAppService,
    required this.fallback,
  });

  final TransactionReadModel transaction;
  final AdvanceTransactionDetailOwnerContext owner;
  final AdvanceOrchestrationAppService advanceAppService;
  final _TransactionDetailActionDispatcher fallback;

  @override
  Future<UiActionOutcome<void>> delete() => fallback.delete();

  @override
  Future<UiActionOutcome<void>> changeNote(String? value) =>
      fallback.changeNote(value);

  @override
  Future<UiActionOutcome<void>> changeOccurredAt(DateTime value) =>
      fallback.changeOccurredAt(value);

  @override
  Future<UiActionOutcome<void>> changePostedAt(DateTime value) =>
      fallback.changePostedAt(value);

  @override
  Future<UiActionOutcome<void>> changeSettlementAccount(
    String accountId, {
    String? currentAccountId,
  }) async {
    final allocations = singleAllocation(
      accountId: accountId,
      amount: transaction.amountOf(TransactionRole.settlementIn),
    );
    switch (transaction.businessPurpose) {
      case BusinessPurpose.advance:
        await advanceAppService.editAdvance(
          EditAdvanceWorkflowCommand(
            transactionId: transaction.id,
            scenario: owner.scenario,
            settlementAllocations: singleAllocation(
              accountId: accountId,
              amount: transaction.primaryAmount,
            ),
          ),
        );
        return const UiActionOutcome.success(null);
      case BusinessPurpose.advanceCollection:
        await advanceAppService.editCollection(
          EditAdvanceCollectionWorkflowCommand(
            transactionId: transaction.id,
            settlementAllocations: allocations,
          ),
        );
        return const UiActionOutcome.success(null);
      case BusinessPurpose.advanceSettlement:
        await advanceAppService.editSettlement(
          EditAdvanceSettlementWorkflowCommand(
            transactionId: transaction.id,
            settlementAllocations: allocations,
          ),
        );
        return const UiActionOutcome.success(null);
      case BusinessPurpose.refund:
        await advanceAppService.editRefund(
          EditAdvanceRefundWorkflowCommand(
            transactionId: transaction.id,
            amount: transaction.primaryAmount,
            categoryAllocations: [
              for (final line in transaction.linesOf(
                TransactionRole.advanceExpenseCategory,
              ))
                if (line.accountId != null)
                  AccountAmountAllocation(
                    accountId: line.accountId!,
                    amount: line.amount,
                  ),
            ],
            settlementAllocations: allocations,
            occurredAt: transaction.occurredAt,
          ),
        );
        return const UiActionOutcome.success(null);
      default:
        return fallback.changeSettlementAccount(
          accountId,
          currentAccountId: currentAccountId,
        );
    }
  }
}
