import '../entity/transaction_group.dart';
import '../service/mutation/transaction_group_rewrite_plan.dart';

abstract interface class TransactionGroupRepository {
  Future<TransactionGroup?> findByParentId(String parentTransactionId);

  Future<TransactionGroup?> findByTransactionId(String transactionId);

  Future<void> applyRewrite(TransactionGroupRewritePlan plan);

  Future<void> deleteGroup(String parentTransactionId);

  Future<void> deleteChild(String childTransactionId);
}
