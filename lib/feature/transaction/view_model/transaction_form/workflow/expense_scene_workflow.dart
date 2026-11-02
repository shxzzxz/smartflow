part of 'transaction_form_workflow.dart';

final class _ExpenseSceneFormWorkflow {
  const _ExpenseSceneFormWorkflow(this._service);

  final AdvanceOrchestrationAppService _service;

  Future<void> create({
    required TransactionFormState state,
    required Money amount,
    required String? note,
  }) async {
    final allocations = expenseAllocations(state, amount);
    final advanceReceivableAccountId = selectedAccountId(
      state.advanceReceivableAccountId,
      state.advanceReceivableAccounts,
    );
    await _service.createExpenseScene(
      CreateExpenseSceneWorkflowCommand(
        amount: amount,
        target: expenseSceneTarget(state, advanceReceivableAccountId),
        categoryAllocations: allocations.categories,
        settlementAllocations: allocations.settlements,
        occurredAt: state.occurredAt,
        counterpartyId: state.counterpartyId,
        note: note,
        isExcludedFromStats: state.excludeStats,
        isExcludedFromBudget: state.excludeBudget,
        tagIds: state.selectedTagIds,
      ),
    );
  }

  Future<void> edit({
    required TransactionFormState state,
    required String transactionId,
    required Money amount,
    required String? note,
  }) async {
    final allocations = expenseAllocations(state, amount);
    final advanceReceivableAccountId = selectedAccountId(
      state.advanceReceivableAccountId,
      state.advanceReceivableAccounts,
    );
    await _service.editExpenseScene(
      EditExpenseSceneWorkflowCommand(
        transactionId: transactionId,
        target: expenseSceneTarget(state, advanceReceivableAccountId),
        amount: amount,
        categoryAllocations: allocations.categories,
        settlementAllocations: allocations.settlements,
        occurredAt: state.occurredAt,
        counterpartyId: counterpartyPatch(state.counterpartyId),
        note: stringPatch(note),
        isExcludedFromStats: state.excludeStats,
        isExcludedFromBudget: state.excludeBudget,
        tagIds: state.selectedTagIds,
      ),
    );
  }
}
