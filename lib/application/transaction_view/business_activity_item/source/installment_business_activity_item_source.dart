import '../../../credit/credit_query_api.dart';
import '../../../ledger/transaction/query/transaction_read_models.dart';
import '../../business_activity/query/business_activity_queries.dart';
import '../query/business_activity_item_read_models.dart';
import 'business_activity_item_source.dart';

final class InstallmentBusinessActivityItemSource
    extends BusinessActivityItemSource {
  const InstallmentBusinessActivityItemSource(this._query);

  final InstallmentQueryService _query;

  @override
  Set<String> get supportedOwnerTypes => const {installmentOwnerType};

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
    return _query.watchInstallment(ownerId);
  }

  Map<String, InstallmentBusinessActivityItemRequest> _requests(
    Iterable<TransactionReadModel> transactions,
  ) {
    return {
      for (final transaction in transactions)
        if (transaction.ownership case final ownership?)
          transaction.id: InstallmentBusinessActivityItemRequest(
            installmentId: ownership.ownerId,
            businessPurpose: transaction.businessPurpose,
          ),
    };
  }

  BusinessActivityItem? _map(
    TransactionReadModel transaction,
    InstallmentBusinessActivityItemProjection? item,
  ) {
    final ownership = transaction.ownership;
    if (ownership == null || item == null) return null;
    return InstallmentBusinessActivityItem(
      activityKey: BusinessActivityKey(
        type: ownership.ownerType,
        id: ownership.ownerId,
      ),
      itemKey: item.itemKey,
      role: item.role,
      occurredAt: transaction.occurredAt,
      projections: [
        BusinessActivityItemProjection(transactionId: transaction.id),
      ],
      installmentType: item.installmentType,
      factKind: item.factKind,
    );
  }
}
