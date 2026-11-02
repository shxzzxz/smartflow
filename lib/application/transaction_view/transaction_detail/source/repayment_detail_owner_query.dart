import '../../../../domain/ledger/valobj/transaction_ownership.dart';
import '../../../credit/credit_query_api.dart';
import '../query/port/transaction_detail_owner_query.dart';
import '../query/transaction_detail_context_read_models.dart';

final class RepaymentDetailOwnerQuery implements TransactionDetailOwnerQuery {
  const RepaymentDetailOwnerQuery(this._query);

  final CreditTransactionViewQueryService _query;

  @override
  Set<String> get supportedOwnerTypes => const {creditRepaymentOwnerType};

  @override
  Future<TransactionDetailOwnerContext?> find(
    TransactionOwnership ownership,
  ) async {
    final summaries = await _query.findRepaymentSummaries({ownership.ownerId});
    return _map(ownership, summaries[ownership.ownerId]);
  }

  @override
  Stream<TransactionDetailOwnerContext?> watch(TransactionOwnership ownership) {
    return _query
        .watchRepaymentSummary(ownership.ownerId)
        .map((summary) => _map(ownership, summary));
  }

  TransactionDetailOwnerContext? _map(
    TransactionOwnership ownership,
    CreditRepaymentBusinessItemSummary? summary,
  ) {
    if (summary == null) return null;
    return RepaymentTransactionDetailOwnerContext(
      ownerType: creditRepaymentOwnerType,
      ownerId: ownership.ownerId,
      repaymentType: summary.repaymentType,
      targetType: summary.targetType,
      targetId: summary.targetId,
    );
  }
}
