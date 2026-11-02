part of 'transaction_form_workflow.dart';

final class _AmortizationFormWorkflow {
  const _AmortizationFormWorkflow(this._service);

  final AmortizationPlanAppService _service;

  Future<void> create({
    required TransactionFormState state,
    required Money amount,
    required String? note,
    required AmortizationConfigurationDraft? configuration,
  }) async {
    final kind = state.amortizationKind;
    if (kind == null) {
      throw invalidCommandException('当前交易不是摊销');
    }
    if (configuration == null) {
      throw invalidCommandException('请先完成摊销配置');
    }
    final categoryAllocations = state.entryMode == TransactionEntryMode.normal
        ? [
            if ((state.mode == TransactionFormMode.expense
                    ? state.expenseCategoryId
                    : state.incomeCategoryId)
                case final categoryId?)
              AccountAmountAllocation(accountId: categoryId, amount: amount),
          ]
        : state.categoryAllocations;
    if (categoryAllocations.isEmpty ||
        categoryAllocations.any(
          (allocation) => allocation.amount.minorUnits <= 0,
        ) ||
        sumAllocations(categoryAllocations) != amount) {
      throw invalidCommandException('分类分配合计必须等于交易金额');
    }
    final fundingAllocations = state.entryMode == TransactionEntryMode.normal
        ? [
            if (effectiveAccountId(
                  state.mode == TransactionFormMode.expense
                      ? state.fromAccountId
                      : state.toAccountId,
                  state.fundAccounts,
                )
                case final fundingAccountId?)
              AccountAmountAllocation(
                accountId: fundingAccountId,
                amount: amount,
              ),
          ]
        : state.settlementAllocations;
    if (fundingAllocations.isEmpty ||
        fundingAllocations.any(
          (allocation) => allocation.amount.minorUnits <= 0,
        ) ||
        sumAllocations(fundingAllocations) != amount) {
      throw invalidCommandException('资金分配合计必须等于交易金额');
    }
    final deferralAccountId = effectiveAccountId(
      state.amortizationDeferralAccountId,
      state.amortizationDeferralAccounts,
    );
    if (deferralAccountId == null) {
      throw invalidCommandException(
        kind == AmortizationKind.prepaidExpense ? '请先创建并选择预付账户' : '请先创建并选择预收账户',
      );
    }
    await _service.createPlan(
      CreateAmortizationPlanCommand(
        kind: kind,
        total: amount,
        fundingAllocations: fundingAllocations,
        deferralAccountId: deferralAccountId,
        recognitionAllocations: categoryAllocations,
        firstRecognitionAt: configuration.firstRecognitionAt,
        cadenceUnit: configuration.cadenceUnit,
        cadenceInterval: configuration.cadenceInterval,
        recognitionCount: configuration.recognitionCount,
        occurredAt: state.occurredAt,
        initialIsExcludedFromStats: state.excludeStats,
        initialIsExcludedFromBudget: state.excludeBudget,
        initialCounterpartyId: state.counterpartyId,
        initialNote: note,
        tagIds: state.selectedTagIds,
      ),
    );
  }
}
