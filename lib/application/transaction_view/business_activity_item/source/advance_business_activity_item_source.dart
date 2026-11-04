import '../../../../domain/orchestration/entity/advance_case.dart';
import '../../../../domain/orchestration/service/advance_transaction_fact_policy.dart';
import '../../../../domain/orchestration/valobj/advance_enums.dart';
import '../../../ledger/transaction/query/transaction_read_models.dart';
import '../../../orchestration/advance/query/advance_case_query_service.dart';
import '../../business_activity/query/business_activity_queries.dart';
import '../query/business_activity_item_read_models.dart';
import 'business_activity_item_source.dart';

final class AdvanceBusinessActivityItemSource
    extends BusinessActivityItemSource {
  const AdvanceBusinessActivityItemSource(this._query);

  final AdvanceCaseQueryService _query;

  @override
  Set<String> get supportedOwnerTypes => const {orchestrationAdvanceOwnerType};

  @override
  Future<Map<String, BusinessActivityItem>> findItems(
    Iterable<TransactionReadModel> transactions,
  ) async {
    final values = transactions.toList();
    final cases = await _query.findByIds(_ownerIds(values));
    return {
      for (final transaction in values)
        transaction.id: ?_map(
          transaction,
          cases[transaction.ownership?.ownerId],
        ),
    };
  }

  @override
  Stream<Object?> watchOwnerChanges(String ownerId) {
    return _query.watchById(ownerId);
  }

  Set<String> _ownerIds(Iterable<TransactionReadModel> transactions) => {
    for (final transaction in transactions)
      if (transaction.ownership case final ownership?) ownership.ownerId,
  };

  BusinessActivityItem? _map(
    TransactionReadModel transaction,
    AdvanceCase? advanceCase,
  ) {
    final ownership = transaction.ownership;
    final factKind = resolveAdvanceTransactionFactKind(
      transaction.businessPurpose,
    );
    if (ownership == null || advanceCase == null || factKind == null) {
      return null;
    }
    return AdvanceBusinessActivityItem(
      activityKey: BusinessActivityKey(
        type: ownership.ownerType,
        id: ownership.ownerId,
      ),
      transactionId: transaction.id,
      factKind: factKind,
      scenario: advanceCase.scenario,
      trackingMode: advanceCase.trackingMode,
    );
  }
}
