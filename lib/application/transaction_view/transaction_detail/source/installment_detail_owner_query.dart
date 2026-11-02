import '../../../../domain/ledger/valobj/transaction_ownership.dart';
import '../../../credit/credit_query_api.dart';
import '../query/port/transaction_detail_owner_query.dart';
import '../query/transaction_detail_context_read_models.dart';

final class InstallmentDetailOwnerQuery implements TransactionDetailOwnerQuery {
  const InstallmentDetailOwnerQuery(this._query);

  final CreditTransactionViewQueryService _query;

  @override
  Set<String> get supportedOwnerTypes => const {installmentOwnerType};

  @override
  Future<TransactionDetailOwnerContext?> find(
    TransactionOwnership ownership,
  ) async {
    final summaries = await _query.findInstallmentSummaries({
      ownership.ownerId,
    });
    return _map(ownership, summaries[ownership.ownerId]);
  }

  @override
  Stream<TransactionDetailOwnerContext?> watch(TransactionOwnership ownership) {
    return _query
        .watchInstallmentSummary(ownership.ownerId)
        .map((summary) => _map(ownership, summary));
  }

  TransactionDetailOwnerContext? _map(
    TransactionOwnership ownership,
    CreditInstallmentBusinessItemSummary? summary,
  ) {
    if (summary == null) return null;
    return InstallmentTransactionDetailOwnerContext(
      ownerType: installmentOwnerType,
      ownerId: ownership.ownerId,
      installmentType: summary.installmentType,
      status: summary.status,
      principal: summary.principal,
      remainingPrincipal: summary.remainingPrincipal,
      paidPeriodCount: summary.paidPeriodCount,
      totalPeriodCount: summary.totalPeriodCount,
    );
  }
}
