import '../../../../domain/ledger/valobj/transaction_ownership.dart';
import '../../../../domain/orchestration/valobj/advance_enums.dart';
import '../../../orchestration/advance/query/advance_transaction_view_query_service.dart';
import '../../../orchestration/advance/query/advance_transaction_view_read_models.dart';
import '../query/port/transaction_detail_owner_query.dart';
import '../query/transaction_detail_context_read_models.dart';

final class AdvanceDetailOwnerQuery implements TransactionDetailOwnerQuery {
  const AdvanceDetailOwnerQuery(this._query);

  final AdvanceTransactionViewQueryService _query;

  @override
  Set<String> get supportedOwnerTypes => const {orchestrationAdvanceOwnerType};

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
    AdvanceTransactionViewSummary? summary,
  ) {
    if (summary == null) return null;
    return AdvanceTransactionDetailOwnerContext(
      ownerType: orchestrationAdvanceOwnerType,
      ownerId: ownership.ownerId,
      scenario: summary.scenario,
      trackingMode: summary.trackingMode,
      advanceAmount: summary.advanceAmount,
      receivedAmount: summary.receivedAmount,
      outstanding: summary.outstanding,
      isClosed: summary.isClosed,
      aaPeopleCount: summary.aaPeopleCount,
    );
  }
}
