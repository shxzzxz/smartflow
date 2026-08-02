import '../entity/transaction.dart';

abstract interface class TransactionRepository {
  Future<Transaction?> findById(String transactionId);

  Future<Transaction?> findCompleteById(String transactionId);

  Future<void> save(Transaction transaction);

  Future<void> saveAll(Iterable<Transaction> transactions);

  /// 统计各账户被分录引用的条数，未被引用的账户不出现在结果中。
  Future<Map<String, int>> countEntriesByAccount(Set<String> accountIds);
}
