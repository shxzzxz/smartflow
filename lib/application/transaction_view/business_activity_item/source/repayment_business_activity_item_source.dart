import '../../../credit/credit_query_api.dart';
import '../../../ledger/transaction/query/transaction_read_models.dart';
import '../../business_activity/query/business_activity_queries.dart';
import '../query/business_activity_item_read_models.dart';
import 'business_activity_item_source.dart';

final class RepaymentBusinessActivityItemSource
    extends BusinessActivityItemSource {
  const RepaymentBusinessActivityItemSource(this._query);

  final CreditTransactionViewQueryService _query;

  @override
  Set<String> get supportedOwnerTypes => const {creditRepaymentOwnerType};

  @override
  Future<Map<String, BusinessActivityItem>> findItems(
    Iterable<TransactionReadModel> transactions,
  ) async {
    final values = transactions.toList();
    final summaries = await _query.findRepaymentSummaries(_ownerIds(values));
    return {
      for (final transaction in values)
        transaction.id: ?_map(
          transaction,
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

  BusinessActivityItem? _map(
    TransactionReadModel transaction,
    CreditRepaymentBusinessActivitySummary? summary,
  ) {
    final ownership = transaction.ownership;
    if (ownership == null || summary == null) return null;
    return RepaymentBusinessActivityItem(
      activityKey: BusinessActivityKey(
        type: summary.activityType,
        id: summary.activityId,
      ),
      transactionId: transaction.id,
      role: summary.role,
      repaymentId: summary.repaymentId,
      repaymentType: summary.repaymentType,
      targetType: summary.targetType,
      targetId: summary.targetId,
    );
  }
}
