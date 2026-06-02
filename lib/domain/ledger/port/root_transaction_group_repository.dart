import '../entity/root_transaction_group.dart';

abstract interface class RootTransactionGroupRepository {
  Future<RootTransactionGroup?> findByRootId(String rootTransactionId);

  Future<RootTransactionGroup?> findByTransactionId(String transactionId);
}
