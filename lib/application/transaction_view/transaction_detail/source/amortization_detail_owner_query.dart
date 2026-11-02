import '../../../../domain/ledger/valobj/transaction_ownership.dart';
import '../../../../domain/orchestration/valobj/amortization_enums.dart';
import '../../../orchestration/amortization/query/amortization_transaction_view_query_service.dart';
import '../../../orchestration/amortization/query/amortization_transaction_view_read_models.dart';
import '../query/port/transaction_detail_owner_query.dart';
import '../query/transaction_detail_context_read_models.dart';

final class AmortizationDetailOwnerQuery
    implements TransactionDetailOwnerQuery {
  const AmortizationDetailOwnerQuery(this._query);

  final AmortizationTransactionViewQueryService _query;

  @override
  Set<String> get supportedOwnerTypes => const {
    orchestrationAmortizationOwnerType,
  };

  @override
  Future<TransactionDetailOwnerContext?> find(
    TransactionOwnership ownership,
  ) async {
    final summaries = await _query.findSummaries({ownership.ownerId});
    return _map(ownership, summaries[ownership.ownerId]);
  }

  @override
  Stream<TransactionDetailOwnerContext?> watch(TransactionOwnership ownership) {
    return _query
        .watchSummary(ownership.ownerId)
        .map((summary) => _map(ownership, summary));
  }

  TransactionDetailOwnerContext? _map(
    TransactionOwnership ownership,
    AmortizationTransactionViewSummary? summary,
  ) {
    if (summary == null) return null;
    return AmortizationTransactionDetailOwnerContext(
      ownerType: orchestrationAmortizationOwnerType,
      ownerId: ownership.ownerId,
      initialTransactionId: summary.initialTransactionId,
      kind: summary.kind,
      status: summary.status,
      originalAmount: summary.originalAmount,
      recognizedAmount: summary.recognizedAmount,
      remainingAmount: summary.remainingAmount,
      postedPeriodCount: summary.postedPeriodCount,
      totalPeriodCount: summary.totalPeriodCount,
      currentPeriodSequence: summary.currentPeriodSequence,
      currentPeriodDueAt: summary.currentPeriodDueAt,
      currentPeriodAmount: summary.currentPeriodAmount,
    );
  }
}
