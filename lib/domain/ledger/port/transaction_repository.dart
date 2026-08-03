import '../entity/transaction.dart';

abstract interface class TransactionRepository {
  Future<Transaction?> findById(String transactionId);

  Future<Transaction?> findCompleteById(String transactionId);

  Future<void> save(Transaction transaction);

  Future<void> saveAll(Iterable<Transaction> transactions);

  /// 统计各账户被分录引用的条数，未被引用的账户不出现在结果中。
  Future<Map<String, int>> countEntriesByAccount(Set<String> accountIds);

  /// 统计各分类被交易行 reimbursement_expense_account_id 引用的条数。
  /// 未结束的报销垫付只以该列引用支出分类，不产生分类分录。
  Future<Map<String, int>> countReimbursementExpenseRefs(Set<String> accountIds);
}
