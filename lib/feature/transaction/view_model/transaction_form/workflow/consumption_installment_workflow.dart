part of '../transaction_form_view_model.dart';

final class _ConsumptionInstallmentFormWorkflow {
  const _ConsumptionInstallmentFormWorkflow(this._service);

  final ConsumptionInstallmentAppService _service;

  Future<void> create({
    required TransactionFormState state,
    required Money amount,
    required String? note,
    required ConsumptionInstallmentConfiguration? configuration,
  }) async {
    if (configuration == null) {
      throw invalidCommandException('请先完成分期配置');
    }
    final categoryAllocations = switch (state.entryMode) {
      TransactionEntryMode.normal => [
        if (state.expenseCategoryId case final categoryId?)
          ConsumptionInstallmentAllocation(
            accountId: categoryId,
            amount: amount,
          ),
      ],
      TransactionEntryMode.allocated => [
        for (final allocation in state.categoryAllocations)
          ConsumptionInstallmentAllocation(
            accountId: allocation.accountId,
            amount: allocation.amount,
          ),
      ],
    };
    if (categoryAllocations.isEmpty) {
      throw invalidCommandException('请至少添加一个支出分类');
    }
    final categoryTotal = categoryAllocations.fold<Money>(
      Money.zero(),
      (total, allocation) => total + allocation.amount,
    );
    if (categoryTotal != amount) {
      throw invalidCommandException('分类分配合计必须等于成交价');
    }

    final liabilityAccountId = effectiveAccountId(
      state.fromAccountId,
      state.creditAccounts,
    );
    if (liabilityAccountId == null) {
      throw invalidCommandException('请选择分期账户');
    }
    final List<AccountAmountAllocation> settlementAllocations =
        state.entryMode == TransactionEntryMode.allocated
        ? state.settlementAllocations
        : singleAllocation(accountId: liabilityAccountId, amount: amount);
    if (settlementAllocations.isEmpty ||
        settlementAllocations.any(
          (allocation) => allocation.amount.minorUnits <= 0,
        )) {
      throw invalidCommandException('请完成有效的支付分配');
    }
    if (sumAllocations(settlementAllocations) != amount) {
      throw invalidCommandException('支付分配合计必须等于成交价');
    }
    final installmentAllocation = settlementAllocations
        .where((allocation) => allocation.accountId == liabilityAccountId)
        .firstOrNull;
    if (installmentAllocation == null ||
        installmentAllocation.amount.minorUnits <= 0) {
      throw invalidCommandException('请选择包含在支付分配中的分期账户');
    }

    await _service.create(
      CreateConsumptionInstallmentCommand(
        liabilityAccountId: liabilityAccountId,
        amount: amount,
        categoryAllocations: categoryAllocations,
        settlementAllocations: [
          for (final allocation in settlementAllocations)
            ConsumptionInstallmentAllocation(
              accountId: allocation.accountId,
              amount: allocation.amount,
            ),
        ],
        borrowingDate: configuration.borrowingDate,
        occurredAt: state.occurredAt,
        counterpartyId: state.counterpartyId,
        note: note,
        tagIds: state.selectedTagIds,
        isExcludedFromStats: state.excludeStats,
        isExcludedFromBudget: state.excludeBudget,
        stageTerms: configuration.stageTerms,
      ),
    );
  }
}
