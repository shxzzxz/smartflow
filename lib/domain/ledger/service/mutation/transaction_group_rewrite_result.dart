import '../../entity/account.dart';
import '../../entity/transaction.dart';
import '../../entity/transaction_group.dart';
import 'transaction_group_rewrite_plan.dart';

class TransactionGroupRewriteResult {
  const TransactionGroupRewriteResult({
    required this.plan,
    required this.accounts,
    required this.currentTransaction,
  });

  final TransactionGroupRewritePlan plan;
  final List<Account> accounts;
  final Transaction currentTransaction;

  TransactionGroup get currentGroup => plan.currentGroup;
}
