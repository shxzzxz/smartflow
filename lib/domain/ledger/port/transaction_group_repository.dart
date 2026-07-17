import '../entity/transaction_group.dart';

abstract interface class TransactionGroupRepository {
  Future<TransactionGroup?> findByParentId(String parentTransactionId);

  Future<TransactionGroup?> findByTransactionId(String transactionId);
}
