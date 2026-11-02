part of 'transaction_form_view_model.dart';

extension InstallmentTransactionFormInteractions on TransactionFormViewModel {
  Money applyConsumptionInstallmentAmount(Money loanAmount) {
    if (loanAmount.minorUnits <= 0) {
      throw _invalidCommandException('贷款金额必须大于零');
    }
    final current = _currentState;
    if (current == null ||
        current.mode != TransactionFormMode.expense ||
        current.expenseScene !=
            TransactionExpenseScene.consumptionInstallment) {
      throw _invalidCommandException('当前交易不是消费分期');
    }
    if (current.entryMode == TransactionEntryMode.normal) {
      return loanAmount;
    }
    final liabilityAccountId = selectedAccountId(
      current.fromAccountId,
      current.creditAccounts,
    );
    if (liabilityAccountId == null) {
      throw _invalidCommandException('请选择分期账户');
    }
    final settlements = [...current.settlementAllocations];
    final installmentIndex = settlements.indexWhere(
      (allocation) => allocation.accountId == liabilityAccountId,
    );
    if (installmentIndex < 0) {
      throw _invalidCommandException('分期账户必须包含在支付分配中');
    }
    settlements[installmentIndex] = settlements[installmentIndex].copyWith(
      amount: loanAmount,
    );
    final total = sumAllocations(settlements);
    final categories = fitAllocationsToTotal(
      current.categoryAllocations,
      total,
    );
    _update(
      (latest) => latest.copyWith(
        categoryAllocations: categories,
        settlementAllocations: settlements,
      ),
    );
    return total;
  }
}
