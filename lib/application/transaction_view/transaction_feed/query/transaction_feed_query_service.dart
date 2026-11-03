import '../../../ledger/ledger_query_api.dart';
import '../../business_context/query/business_context_stream.dart';
import '../../business_context/query/transaction_business_context_query.dart';
import '../../transaction_detail/query/transaction_detail_context_read_models.dart';

final class TransactionFeedEntry {
  const TransactionFeedEntry({required this.transaction, this.businessContext});

  final TransactionReadModel transaction;
  final TransactionDetailOwnerContext? businessContext;
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
    required TransactionBusinessContextQuery businessContexts,
  }) : _transactions = transactions,
       _businessContexts = businessContexts;

  final TransactionQueryService _transactions;
  final TransactionBusinessContextQuery _businessContexts;

  @override
  Future<List<TransactionFeedEntry>> findTransactions(
    TransactionListQuery query,
  ) async {
    final transactions = await _transactions.findTransactions(query);
    final contexts = await _businessContexts.findContexts(transactions);
    return _entries(transactions, contexts);
  }

  @override
  Stream<List<TransactionFeedEntry>> watchTransactions(
    TransactionListQuery query,
  ) {
    return switchMapStreams(
      _transactions.watchTransactions(query),
      (transactions) => _businessContexts
          .watchContexts(transactions)
          .map((contexts) => _entries(transactions, contexts)),
    );
  }

  List<TransactionFeedEntry> _entries(
    List<TransactionReadModel> transactions,
    Map<String, TransactionDetailOwnerContext> contexts,
  ) {
    return [
      for (final transaction in transactions)
        TransactionFeedEntry(
          transaction: transaction,
          businessContext: contexts[transaction.id],
        ),
    ];
  }
}
