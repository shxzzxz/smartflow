import '../../../credit/credit_query_api.dart';
import '../../../ledger/transaction/query/transaction_read_models.dart';
import '../../transaction_detail/query/transaction_detail_context_read_models.dart';
import 'transaction_business_context_source.dart';

final class RepaymentBusinessContextSource
    extends TransactionBusinessContextSource {
  const RepaymentBusinessContextSource(this._query);

  final CreditTransactionViewQueryService _query;

  @override
  Set<String> get supportedOwnerTypes => const {creditRepaymentOwnerType};

  @override
  Future<Map<String, TransactionDetailOwnerContext>> findContexts(
    Iterable<TransactionReadModel> transactions,
  ) async {
    final values = transactions.toList();
    final summaries = await _query.findRepaymentSummaries(_ownerIds(values));
    return {
      for (final transaction in values)
        transaction.id: ?_map(
          transaction.ownership?.ownerId,
          summaries[transaction.ownership?.ownerId],
        ),
    };
  }

  @override
  Stream<Object?> watchOwnerChanges(String ownerId) {
    return _query.watchRepaymentSummary(ownerId);
  }

  Set<String> _ownerIds(Iterable<TransactionReadModel> transactions) => {
    for (final transaction in transactions)
      if (transaction.ownership case final ownership?) ownership.ownerId,
  };

  TransactionDetailOwnerContext? _map(
    String? ownerId,
    CreditRepaymentBusinessItemSummary? summary,
  ) {
    if (ownerId == null || summary == null) return null;
    return RepaymentTransactionDetailOwnerContext(
      ownerType: creditRepaymentOwnerType,
      ownerId: ownerId,
      repaymentType: summary.repaymentType,
      targetType: summary.targetType,
      targetId: summary.targetId,
    );
  }
}
