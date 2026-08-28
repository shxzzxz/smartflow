import '../entity/transaction.dart';

abstract interface class TransactionRepository {
  Future<Transaction?> findById(String transactionId);

  Future<Transaction?> findCompleteById(String transactionId);

  Future<void> save(Transaction transaction);

  Future<void> saveAll(Iterable<Transaction> transactions);

  /// 只更新交易头字段，不写分项或分录。
  ///
  /// 供备注、时间、对手方、统计标记与归属等轻量更新使用。
  Future<void> updateAll(Iterable<Transaction> transactions);

  /// 统计各账户被分录引用的条数，未被引用的账户不出现在结果中。
  Future<Map<String, int>> countEntriesByAccount(Set<String> accountIds);

  /// 统计各分类被 reimbursementExpenseCategory 分项引用的条数。
  /// 未结束的报销垫付只以该分项引用支出分类，不产生分类分录。
  Future<Map<String, int>> countReimbursementExpenseRefs(
    Set<String> accountIds,
  );
}
