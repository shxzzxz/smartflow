import '../../../core/patch/patch.dart';
import '../entities/account.dart';
import '../entities/transaction_ownership.dart';
import '../ledger/posting_protocol.dart';

abstract interface class PostingRepository {
  Future<List<Account>> findAccountsByIds(Set<int> ids);

  Future<PostTransactionResult> postTransaction({
    required PostTransactionCommand command,
    required Map<int, int> balanceDeltasMinor,
  });

  Future<List<PostTransactionResult>> mutateTransactions({
    required List<TransactionStateUpdate> stateUpdates,
    required List<PostTransactionMutation> posts,
  });

  Future<void> updateTransactionMetadata({
    required int transactionId,
    Patch<String>? note,
    bool? isExcludedFromStats,
    bool? isExcludedFromBudget,
  });

  Future<void> updateTransactionOwnership({
    required int transactionId,
    required TransactionOwnership ownership,
  });

  Future<void> updateTransactionBasics({
    required int transactionId,
    DateTime? occurredAt,
    List<EntryAccountReassignment> entryAccountReassignments = const [],
  });
}
