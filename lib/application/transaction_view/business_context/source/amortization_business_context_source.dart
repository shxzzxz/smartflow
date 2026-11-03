import '../../../../domain/orchestration/valobj/amortization_enums.dart';
import '../../../ledger/transaction/query/transaction_read_models.dart';
import '../../../orchestration/amortization/query/amortization_transaction_context_query.dart';
import '../query/transaction_business_context_read_models.dart';
import 'transaction_business_context_source.dart';

final class AmortizationBusinessContextSource
    extends TransactionBusinessContextSource {
  const AmortizationBusinessContextSource(this._query);

  final AmortizationTransactionContextQueryService _query;

  @override
  Set<String> get supportedOwnerTypes => const {
    orchestrationAmortizationOwnerType,
  };

  @override
  Future<Map<String, TransactionBusinessContext>> findContexts(
    Iterable<TransactionReadModel> transactions,
  ) async {
    final contexts = await _query.findForTransactions(
      _groupByOwner(transactions),
    );
    return {for (final entry in contexts.entries) entry.key: _map(entry.value)};
  }

  @override
  Stream<Map<String, TransactionBusinessContext>> watchContexts(
    Iterable<TransactionReadModel> transactions,
  ) {
    return _query
        .watchForTransactions(_groupByOwner(transactions))
        .map(
          (contexts) => {
            for (final entry in contexts.entries) entry.key: _map(entry.value),
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

  TransactionBusinessContext _map(AmortizationTransactionContext context) {
    return AmortizationTransactionBusinessContext(
      ownerType: orchestrationAmortizationOwnerType,
      ownerId: context.planId,
      initialTransactionId: context.initialTransactionId,
      kind: context.kind,
      status: context.status,
      originalAmount: context.originalAmount,
      recognizedAmount: context.recognizedAmount,
      remainingAmount: context.remainingAmount,
      postedPeriodCount: context.postedPeriodCount,
      totalPeriodCount: context.totalPeriodCount,
      categoryAccountIds: context.categoryAccountIds,
      occurrencePeriodSequence: context.occurrencePeriodSequence,
      occurrencePeriodDueAt: context.occurrencePeriodDueAt,
      currentPeriodSequence: context.currentPeriodSequence,
      currentPeriodDueAt: context.currentPeriodDueAt,
      currentPeriodAmount: context.currentPeriodAmount,
      factKind: context.factKind,
      refundId: context.refundId,
      terminationId: context.terminationId,
    );
  }
}
