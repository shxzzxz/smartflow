import '../../../ledger/transaction/query/transaction_read_models.dart';
import '../../../orchestration/amortization/query/amortization_business_activity_item_query.dart';
import '../../../../domain/orchestration/valobj/amortization_enums.dart';
import '../../business_activity/query/business_activity_queries.dart';
import '../query/business_activity_item_read_models.dart';
import 'business_activity_item_source.dart';

final class AmortizationBusinessActivityItemSource
    extends BusinessActivityItemSource {
  const AmortizationBusinessActivityItemSource(this._query);

  final AmortizationBusinessActivityItemQueryService _query;

  @override
  Set<String> get supportedOwnerTypes => const {
    orchestrationAmortizationOwnerType,
  };

  @override
  Future<Map<String, BusinessActivityItem>> findItems(
    Iterable<TransactionReadModel> transactions,
  ) async {
    final items = await _query.findForTransactions(_groupByOwner(transactions));
    return {for (final entry in items.entries) entry.key: _map(entry.value)};
  }

  @override
  Stream<Map<String, BusinessActivityItem>> watchItems(
    Iterable<TransactionReadModel> transactions,
  ) {
    return _query
        .watchForTransactions(_groupByOwner(transactions))
        .map(
          (items) => {
            for (final entry in items.entries) entry.key: _map(entry.value),
          },
        );
  }

  @override
  Stream<Object?> watchOwnerChanges(String ownerId) {
    return _query.watchForTransactions({ownerId: const {}});
  }

  Map<String, Set<String>> _groupByOwner(
    Iterable<TransactionReadModel> transactions,
  ) {
    final transactionIdsByPlanId = <String, Set<String>>{};
    for (final transaction in transactions) {
      final ownership = transaction.ownership;
      if (ownership == null) continue;
      transactionIdsByPlanId
          .putIfAbsent(ownership.ownerId, () => {})
          .add(transaction.id);
    }
    return transactionIdsByPlanId;
  }

  BusinessActivityItem _map(AmortizationBusinessActivityItemProjection item) {
    return AmortizationBusinessActivityItem(
      activityKey: BusinessActivityKey(
        type: orchestrationAmortizationOwnerType,
        id: item.planId,
      ),
      transactionId: item.transactionId,
      kind: item.kind,
      factKind: item.factKind,
      role: item.role,
      localCategoryAllocations: item.localCategoryAllocations,
      occurrencePeriodSequence: item.occurrencePeriodSequence,
      occurrencePeriodDueAt: item.occurrencePeriodDueAt,
      refundId: item.refundId,
      terminationId: item.terminationId,
    );
  }
}
