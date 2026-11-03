import '../../../ledger/transaction/query/transaction_read_models.dart';
import '../../transaction_detail/query/transaction_detail_context_read_models.dart';
import '../query/business_context_stream.dart';

/// Business-domain adapter used by transaction detail and transaction feeds.
///
/// Sources receive the actual transactions already selected by the ledger.
/// They must batch-load their owner facts and return contexts only for the
/// requested transaction IDs.
abstract class TransactionBusinessContextSource {
  const TransactionBusinessContextSource();

  Set<String> get supportedOwnerTypes;

  Future<Map<String, TransactionDetailOwnerContext>> findContexts(
    Iterable<TransactionReadModel> transactions,
  );

  Stream<Object?> watchOwnerChanges(String ownerId);

  Stream<Map<String, TransactionDetailOwnerContext>> watchContexts(
    Iterable<TransactionReadModel> transactions,
  ) {
    final values = transactions.toList();
    final ownerIds = {
      for (final transaction in values)
        if (transaction.ownership case final ownership?) ownership.ownerId,
    };
    if (ownerIds.isEmpty) return Stream.value(const {});
    return combineLatestStreams(
      ownerIds.map(watchOwnerChanges),
    ).asyncMap((_) => findContexts(values));
  }
}
