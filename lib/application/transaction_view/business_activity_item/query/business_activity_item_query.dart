import '../../../ledger/transaction/query/transaction_read_models.dart';
import '../../business_activity/query/business_activity_queries.dart';
import '../../transaction_view_query_streams.dart';
import '../source/business_activity_item_source.dart';
import 'business_activity_item_read_models.dart';

abstract interface class BusinessActivityItemQuery {
  Future<Map<String, BusinessActivityItem>> findItems(
    Iterable<TransactionReadModel> transactions,
  );

  Stream<Map<String, BusinessActivityItem>> watchItems(
    Iterable<TransactionReadModel> transactions,
  );
}

final class BusinessActivityItemQueryImpl implements BusinessActivityItemQuery {
  BusinessActivityItemQueryImpl({
    required Iterable<BusinessActivityItemSource> sources,
  }) : _sources = List.unmodifiable(sources);

  final List<BusinessActivityItemSource> _sources;

  @override
  Future<Map<String, BusinessActivityItem>> findItems(
    Iterable<TransactionReadModel> transactions,
  ) async {
    final values = transactions.toList();
    final groups = _groupBySource(values);
    final loaded = await Future.wait([
      for (final entry in groups.entries) entry.key.findItems(entry.value),
    ]);
    return _complete(values, loaded);
  }

  @override
  Stream<Map<String, BusinessActivityItem>> watchItems(
    Iterable<TransactionReadModel> transactions,
  ) {
    final values = transactions.toList();
    final groups = _groupBySource(values);
    if (groups.isEmpty) {
      return Stream.value(_complete(values, const []));
    }
    return combineLatestStreams([
      for (final entry in groups.entries) entry.key.watchItems(entry.value),
    ]).map((loaded) => _complete(values, loaded));
  }

  Map<BusinessActivityItemSource, List<TransactionReadModel>> _groupBySource(
    List<TransactionReadModel> transactions,
  ) {
    final groups = <BusinessActivityItemSource, List<TransactionReadModel>>{};
    for (final transaction in transactions) {
      final ownership = transaction.ownership;
      if (ownership == null) continue;
      final source = _sourceFor(ownership.ownerType);
      if (source == null) continue;
      groups.putIfAbsent(source, () => []).add(transaction);
    }
    return groups;
  }

  Map<String, BusinessActivityItem> _complete(
    List<TransactionReadModel> transactions,
    Iterable<Map<String, BusinessActivityItem>> loaded,
  ) {
    final requestedIds = {
      for (final transaction in transactions) transaction.id,
    };
    final items = <String, BusinessActivityItem>{
      for (final values in loaded)
        for (final entry in values.entries)
          if (requestedIds.contains(entry.key)) entry.key: entry.value,
    };
    for (final transaction in transactions) {
      final ownership = transaction.ownership;
      if (ownership == null || items.containsKey(transaction.id)) continue;
      items[transaction.id] = UnknownBusinessActivityItem(
        activityKey: BusinessActivityKey(
          type: ownership.ownerType,
          id: ownership.ownerId,
        ),
        transactionId: transaction.id,
      );
    }
    return items;
  }

  BusinessActivityItemSource? _sourceFor(String ownerType) {
    for (final source in _sources) {
      if (source.supportedOwnerTypes.contains(ownerType)) return source;
    }
    return null;
  }
}
