import '../../../../domain/ledger/valobj/transaction_ownership.dart';
import '../../../credit/credit_query_api.dart';
import '../../../ledger/transaction/query/transaction_read_models.dart';
import '../query/port/transaction_detail_owner_query.dart';
import '../query/transaction_detail_context_read_models.dart';

final class InstallmentDetailOwnerQuery implements TransactionDetailOwnerQuery {
  const InstallmentDetailOwnerQuery(this._query);

  final InstallmentQueryService _query;

  @override
  Set<String> get supportedOwnerTypes => const {installmentOwnerType};

  @override
  Future<TransactionDetailOwnerContext?> find(
    TransactionOwnership ownership,
    TransactionReadModel anchorTransaction,
  ) async {
    return _map(ownership, await _query.findInstallment(ownership.ownerId));
  }

  @override
  Stream<TransactionDetailOwnerContext?> watch(
    TransactionOwnership ownership,
    TransactionReadModel anchorTransaction,
  ) {
    return _query
        .watchInstallment(ownership.ownerId)
        .map((installment) => _map(ownership, installment));
  }

  TransactionDetailOwnerContext? _map(
    TransactionOwnership ownership,
    InstallmentDTO? installment,
  ) {
    if (installment == null) return null;
    return InstallmentTransactionDetailOwnerContext(
      ownerType: installmentOwnerType,
      ownerId: ownership.ownerId,
      installmentType: installment.installmentType,
      status: installment.status,
      principal: installment.principal,
      remainingPrincipal: installment.repaymentProgress.remainingPrincipal,
      paidPeriodCount: installment.repaymentProgress.paidPeriodCount,
      totalPeriodCount: installment.repaymentProgress.totalPeriodCount,
    );
  }
}
