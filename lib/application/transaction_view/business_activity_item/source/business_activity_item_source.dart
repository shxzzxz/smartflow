import '../../../ledger/transaction/query/transaction_read_models.dart';
import '../../transaction_view_query_streams.dart';
import '../query/business_activity_item_read_models.dart';

/// Consumer-side adapter for the business attributes of hit transactions.
abstract class BusinessActivityItemSource {
  const BusinessActivityItemSource();

  Set<String> get supportedOwnerTypes;

  Future<Map<String, BusinessActivityItem>> findItems(
    Iterable<TransactionReadModel> transactions,
  );

  Stream<Object?> watchOwnerChanges(String ownerId);

  Stream<Map<String, BusinessActivityItem>> watchItems(
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
    ).asyncMap((_) => findItems(values));
  }
}
