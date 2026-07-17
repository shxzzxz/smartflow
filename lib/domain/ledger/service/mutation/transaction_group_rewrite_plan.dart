import '../../entity/transaction.dart';
import '../../entity/transaction_group.dart';

class TransactionRewrite {
  const TransactionRewrite({required this.before, required this.after});

  final Transaction before;
  final Transaction after;
}

class TransactionGroupRewritePlan {
  const TransactionGroupRewritePlan({
    required this.rewrites,
    required this.rowUpdates,
    required this.currentGroup,
  });

  final List<TransactionRewrite> rewrites;
  final List<Transaction> rowUpdates;
  final TransactionGroup currentGroup;
}
