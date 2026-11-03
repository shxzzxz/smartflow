import '../../../../domain/ledger/valobj/transaction_ownership.dart';
import '../../../../domain/orchestration/entity/advance_case.dart';
import '../../../../domain/orchestration/valobj/advance_enums.dart';
import '../../../ledger/transaction/query/transaction_read_models.dart';
import '../../../orchestration/advance/query/advance_case_query_service.dart';
import '../query/port/transaction_detail_owner_query.dart';
import '../query/transaction_detail_context_read_models.dart';

final class AdvanceDetailOwnerQuery implements TransactionDetailOwnerQuery {
  const AdvanceDetailOwnerQuery(this._query);

  final AdvanceCaseQueryService _query;

  @override
  Set<String> get supportedOwnerTypes => const {orchestrationAdvanceOwnerType};

  @override
  Future<TransactionDetailOwnerContext?> find(
    TransactionOwnership ownership,
    TransactionReadModel anchorTransaction,
  ) async {
    return _map(
      ownership,
      await _query.findById(ownership.ownerId),
      anchorTransaction,
    );
  }

  @override
  Stream<TransactionDetailOwnerContext?> watch(
    TransactionOwnership ownership,
    TransactionReadModel anchorTransaction,
  ) {
    return _query
        .watchById(ownership.ownerId)
        .map((advanceCase) => _map(ownership, advanceCase, anchorTransaction));
  }

  TransactionDetailOwnerContext? _map(
    TransactionOwnership ownership,
    AdvanceCase? advanceCase,
    TransactionReadModel anchorTransaction,
  ) {
    if (advanceCase == null) return null;
    final facts = anchorTransaction.advanceSummary;
    if (facts == null) {
      throw StateError(
        'Advance facts for anchor transaction ${anchorTransaction.id} were '
        'not found.',
      );
    }
    return AdvanceTransactionDetailOwnerContext(
      ownerType: orchestrationAdvanceOwnerType,
      ownerId: ownership.ownerId,
      scenario: advanceCase.scenario,
      trackingMode: advanceCase.trackingMode,
      advanceAmount: facts.advanceAmount,
      receivedAmount: facts.receivedAmount,
      outstanding: facts.outstanding,
      isClosed: facts.isClosed,
      aaPeopleCount: advanceCase.aaPeopleCount,
    );
  }
}
