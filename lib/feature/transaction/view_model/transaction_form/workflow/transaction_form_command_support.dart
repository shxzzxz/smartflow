part of 'transaction_form_workflow.dart';

BusinessException invalidCommandException(String message) {
  return BusinessException(
    LedgerErrorCode.transactionInvalidCommand,
    message: message,
  );
}

Patch<String?> stringPatch(String? value) {
  return value == null ? const Patch<String?>.clear() : Patch.set(value);
}

Patch<String?> counterpartyPatch(String? value) {
  return value == null
      ? const Patch<String?>.clear()
      : Patch<String?>.set(value);
}

ExpenseSceneTarget expenseSceneTarget(
  TransactionFormState state,
  String? advanceReceivableAccountId,
) {
  if (state.expenseScene == TransactionExpenseScene.consumptionInstallment) {
    throw invalidCommandException('消费分期请完成分期配置后提交');
  }
  if (state.expenseScene == TransactionExpenseScene.ordinary &&
      advanceReceivableAccountId == null) {
    return const OrdinaryExpenseSceneTarget();
  }
  if (advanceReceivableAccountId == null) {
    throw invalidCommandException('请选择垫付账户');
  }
  final scenario =
      state.expenseScene.advanceScenario ?? AdvanceScenario.reimbursement;
  final trackingMode =
      state.expenseScene.advanceTrackingMode ?? AdvanceTrackingMode.itemized;
  return trackingMode == AdvanceTrackingMode.account
      ? AccountAdvanceSceneTarget(
          scenario: scenario,
          aaPeopleCount: state.aaPeopleCount,
          receivableAccountId: advanceReceivableAccountId,
        )
      : ItemizedAdvanceSceneTarget(
          scenario: scenario,
          aaPeopleCount: state.aaPeopleCount,
          receivableAccountId: advanceReceivableAccountId,
        );
}

({
  List<AccountAmountAllocation> categories,
  List<AccountAmountAllocation> settlements,
})
expenseAllocations(TransactionFormState state, Money amount) {
  if (state.entryMode == TransactionEntryMode.normal) {
    final categoryId = state.expenseCategoryId;
    if (categoryId == null) {
      throw invalidCommandException('请选择支出分类');
    }
    final settlementId = effectiveAccountId(
      state.fromAccountId,
      state.expenseSettlementAccounts,
    );
    if (settlementId == null) {
      throw invalidCommandException('请选择支出账户');
    }
    return (
      categories: singleAllocation(accountId: categoryId, amount: amount),
      settlements: singleAllocation(accountId: settlementId, amount: amount),
    );
  }

  final categories = state.categoryAllocations;
  final settlements = state.settlementAllocations;
  if (categories.isEmpty) {
    throw invalidCommandException('请至少添加一个支出分类');
  }
  if (settlements.isEmpty) {
    throw invalidCommandException('请至少添加一个支出账户');
  }
  if (sumAllocations(categories) != amount) {
    throw invalidCommandException('分类分配合计必须等于交易金额');
  }
  if (sumAllocations(settlements) != amount) {
    throw invalidCommandException('支付分配合计必须等于交易金额');
  }
  return (categories: categories, settlements: settlements);
}

({
  List<AccountAmountAllocation> categories,
  List<AccountAmountAllocation> settlements,
})
incomeAllocations(TransactionFormState state, Money amount) {
  if (state.entryMode == TransactionEntryMode.normal) {
    final categoryId = state.incomeCategoryId;
    if (categoryId == null) {
      throw invalidCommandException('请选择收入分类');
    }
    final settlementId = effectiveAccountId(
      state.toAccountId,
      state.settlementAccounts,
    );
    if (settlementId == null) {
      throw invalidCommandException('请选择收入账户');
    }
    return (
      categories: singleAllocation(accountId: categoryId, amount: amount),
      settlements: singleAllocation(accountId: settlementId, amount: amount),
    );
  }

  final categories = state.categoryAllocations;
  final settlements = state.settlementAllocations;
  if (categories.isEmpty) {
    throw invalidCommandException('请至少添加一个收入分类');
  }
  if (settlements.isEmpty) {
    throw invalidCommandException('请至少添加一个收入账户');
  }
  if (sumAllocations(categories) != amount) {
    throw invalidCommandException('收入分配合计必须等于交易金额');
  }
  if (sumAllocations(settlements) != amount) {
    throw invalidCommandException('到账分配合计必须等于交易金额');
  }
  return (categories: categories, settlements: settlements);
}
