abstract interface class SystemAccountResolver {
  Future<String> resolveOpeningBalance();

  Future<String> resolveReimbursementGapIncome();

  Future<String> resolveInterestExpense();

  Future<String> resolveFeeExpense();

  Future<String> resolveDiscountIncome();

  /// 幽灵账户:用于导入 / 修复等场景下"暂时挂在某个语义账户"的占位入口。
  Future<String> resolveGhostAccount();
}
