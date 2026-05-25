abstract interface class SystemAccountResolver {
  Future<int> resolveOpeningBalance();

  Future<int> resolveReimbursementGapIncome();

  Future<int> resolveDebtInterestExpense();

  Future<int> resolveDebtFeeExpense();

  Future<int> resolveDiscountIncome();

  /// 幽灵账户:用于导入 / 修复等场景下"暂时挂在某个语义账户"的占位入口。
  Future<int> resolveGhostAccount();
}
