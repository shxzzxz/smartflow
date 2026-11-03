import '../../../../domain/orchestration/entity/advance_case.dart';
import '../../../../domain/orchestration/valobj/advance_enums.dart';
import '../../../ledger/transaction/query/transaction_read_models.dart';
import '../../../orchestration/advance/query/advance_case_query_service.dart';
import '../query/transaction_business_context_read_models.dart';
import 'transaction_business_context_source.dart';

final class AdvanceBusinessContextSource
    extends TransactionBusinessContextSource {
  const AdvanceBusinessContextSource(this._query);

  final AdvanceCaseQueryService _query;

  @override
  Set<String> get supportedOwnerTypes => const {orchestrationAdvanceOwnerType};

  @override
  Future<Map<String, TransactionBusinessContext>> findContexts(
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

  TransactionBusinessContext? _map(
    TransactionReadModel transaction,
    AdvanceCase? advanceCase,
  ) {
    if (advanceCase == null) return null;
    final facts = transaction.advanceSummary;
    if (facts == null) return null;
    return AdvanceTransactionBusinessContext(
      ownerType: orchestrationAdvanceOwnerType,
      ownerId: advanceCase.id,
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
