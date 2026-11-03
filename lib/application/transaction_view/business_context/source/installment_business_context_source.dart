import '../../../credit/credit_query_api.dart';
import '../../../ledger/transaction/query/transaction_read_models.dart';
import '../../transaction_detail/query/transaction_detail_context_read_models.dart';
import 'transaction_business_context_source.dart';

final class InstallmentBusinessContextSource
    extends TransactionBusinessContextSource {
  const InstallmentBusinessContextSource(this._query);

  final InstallmentQueryService _query;

  @override
  Set<String> get supportedOwnerTypes => const {installmentOwnerType};

  @override
  Future<Map<String, TransactionDetailOwnerContext>> findContexts(
    Iterable<TransactionReadModel> transactions,
  ) async {
    final values = transactions.toList();
    final installments = await _query.findInstallments(_ownerIds(values));
    return {
      for (final transaction in values)
        transaction.id: ?_map(installments[transaction.ownership?.ownerId]),
    };
  }

  @override
  Stream<Object?> watchOwnerChanges(String ownerId) {
    return _query.watchInstallment(ownerId);
  }

  Set<String> _ownerIds(Iterable<TransactionReadModel> transactions) => {
    for (final transaction in transactions)
      if (transaction.ownership case final ownership?) ownership.ownerId,
  };

  TransactionDetailOwnerContext? _map(InstallmentDTO? installment) {
    if (installment == null) return null;
    return InstallmentTransactionDetailOwnerContext(
      ownerType: installmentOwnerType,
      ownerId: installment.id,
      installmentType: installment.installmentType,
      status: installment.status,
      principal: installment.principal,
      remainingPrincipal: installment.repaymentProgress.remainingPrincipal,
      paidPeriodCount: installment.repaymentProgress.paidPeriodCount,
      totalPeriodCount: installment.repaymentProgress.totalPeriodCount,
    );
  }
}
