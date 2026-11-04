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
    final values = transactions.toList();
    final items = await _query.findForTransactions(_groupByOwner(values));
    final transactionsById = {
      for (final transaction in values) transaction.id: transaction,
    };
    return {
      for (final entry in items.entries)
        if (transactionsById[entry.key] case final transaction?)
          entry.key: _map(entry.value, transaction),
    };
  }

  @override
  Stream<Map<String, BusinessActivityItem>> watchItems(
    Iterable<TransactionReadModel> transactions,
  ) {
    final values = transactions.toList();
    final transactionsById = {
      for (final transaction in values) transaction.id: transaction,
    };
    return _query
        .watchForTransactions(_groupByOwner(values))
        .map(
          (items) => {
            for (final entry in items.entries)
              if (transactionsById[entry.key] case final transaction?)
                entry.key: _map(entry.value, transaction),
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

  BusinessActivityItem _map(
    AmortizationBusinessActivityItemProjection item,
    TransactionReadModel transaction,
  ) {
    return AmortizationBusinessActivityItem(
      activityKey: BusinessActivityKey(
        type: orchestrationAmortizationOwnerType,
        id: item.planId,
      ),
      itemKey: item.itemKey,
      role: item.role,
      occurredAt: transaction.occurredAt,
      projections: [
        AmortizationTransactionProjection(
          transactionId: item.transactionId,
          localCategoryAllocations: item.localCategoryAllocations,
          occurrencePeriodSequence: item.occurrencePeriodSequence,
          occurrencePeriodDueAt: item.occurrencePeriodDueAt,
        ),
      ],
      kind: item.kind,
      factKind: item.factKind,
      refundId: item.refundId,
      terminationId: item.terminationId,
    );
  }
}
