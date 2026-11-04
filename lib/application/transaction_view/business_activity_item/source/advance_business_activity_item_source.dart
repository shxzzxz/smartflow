import '../../../../domain/orchestration/valobj/advance_enums.dart';
import '../../../ledger/transaction/query/transaction_read_models.dart';
import '../../../orchestration/advance/query/advance_business_activity_item_query.dart';
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
    final items = await _query.findBusinessActivityItems(_requests(values));
    return {
      for (final transaction in values)
        transaction.id: ?_map(transaction, items[transaction.id]),
    };
  }

  @override
  Stream<Object?> watchOwnerChanges(String ownerId) {
    return _query.watchById(ownerId);
  }

  Map<String, AdvanceBusinessActivityItemRequest> _requests(
    Iterable<TransactionReadModel> transactions,
  ) {
    return {
      for (final transaction in transactions)
        if (transaction.ownership case final ownership?)
          transaction.id: AdvanceBusinessActivityItemRequest(
            advanceCaseId: ownership.ownerId,
            businessPurpose: transaction.businessPurpose,
          ),
    };
  }

  BusinessActivityItem? _map(
    TransactionReadModel transaction,
    AdvanceBusinessActivityItemProjection? item,
  ) {
    final ownership = transaction.ownership;
    if (ownership == null || item == null) {
      return null;
    }
    return AdvanceBusinessActivityItem(
      activityKey: BusinessActivityKey(
        type: ownership.ownerType,
        id: ownership.ownerId,
      ),
      transactionId: transaction.id,
      role: item.role,
      factKind: item.factKind,
      scenario: item.scenario,
      trackingMode: item.trackingMode,
    );
  }
}
