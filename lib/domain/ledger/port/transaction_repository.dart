import '../entity/transaction.dart';

abstract interface class TransactionRepository {
  Future<Transaction?> findById(String transactionId);

  Future<Transaction?> findCompleteById(String transactionId);

  Future<void> save(Transaction transaction);

  Future<void> saveAll(Iterable<Transaction> transactions);

  Future<void> rewriteAll(Iterable<Transaction> transactions);

  Future<void> deleteAll(Set<String> transactionIds);
}
