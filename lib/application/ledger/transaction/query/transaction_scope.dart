class TransactionScopeFilter {
  const TransactionScopeFilter({
    this.excludedFromStats,
    this.excludedFromBudget,
  });

  final bool? excludedFromStats;
  final bool? excludedFromBudget;

  static const TransactionScopeFilter stats = TransactionScopeFilter(
    excludedFromStats: false,
  );

  static const TransactionScopeFilter budget = TransactionScopeFilter(
    excludedFromBudget: false,
  );

  static const TransactionScopeFilter assetLiability = TransactionScopeFilter();

  static const TransactionScopeFilter actual = TransactionScopeFilter();

  static const TransactionScopeFilter all = TransactionScopeFilter();
}
