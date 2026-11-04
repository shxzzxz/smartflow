import '../../../ledger/ledger_query_api.dart';
import '../../business_activity_item/query/business_activity_item_query.dart';
import '../../business_activity_item/query/business_activity_item_read_models.dart';
import '../../transaction_view_query_streams.dart';

final class TransactionFeedEntry {
  const TransactionFeedEntry({required this.transaction, this.businessItem});

  final TransactionReadModel transaction;
  final BusinessActivityItem? businessItem;
}

abstract interface class TransactionFeedQueryService {
  Future<List<TransactionFeedEntry>> findTransactions(
    TransactionListQuery query,
  );

  Stream<List<TransactionFeedEntry>> watchTransactions(
    TransactionListQuery query,
  );
}

final class TransactionFeedQueryServiceImpl
    implements TransactionFeedQueryService {
  const TransactionFeedQueryServiceImpl({
    required TransactionQueryService transactions,
    required BusinessActivityItemQuery businessItems,
  }) : _transactions = transactions,
       _businessItems = businessItems;

  final TransactionQueryService _transactions;
  final BusinessActivityItemQuery _businessItems;

  @override
  Future<List<TransactionFeedEntry>> findTransactions(
    TransactionListQuery query,
  ) async {
    final transactions = await _transactions.findTransactions(query);
    final items = await _businessItems.findItems(transactions);
    return _entries(transactions, items);
  }

  @override
  Stream<List<TransactionFeedEntry>> watchTransactions(
    TransactionListQuery query,
  ) {
    return switchMapStreams(
      _transactions.watchTransactions(query),
      (transactions) => _businessItems
          .watchItems(transactions)
          .map((items) => _entries(transactions, items)),
    );
  }

  List<TransactionFeedEntry> _entries(
    List<TransactionReadModel> transactions,
    Map<String, BusinessActivityItem> items,
  ) {
    return [
      for (final transaction in transactions)
        TransactionFeedEntry(
          transaction: transaction,
          businessItem: items[transaction.id],
        ),
    ];
  }
}
