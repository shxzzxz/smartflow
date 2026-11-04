import '../../../credit/credit_query_api.dart';
import '../../../ledger/transaction/query/transaction_read_models.dart';
import '../../../../domain/credit/service/installment/installment_transaction_fact_policy.dart';
import '../../business_activity/query/business_activity_queries.dart';
import '../query/business_activity_item_read_models.dart';
import 'business_activity_item_source.dart';

final class InstallmentBusinessActivityItemSource
    extends BusinessActivityItemSource {
  const InstallmentBusinessActivityItemSource(this._query);

  final InstallmentQueryService _query;

  @override
  Set<String> get supportedOwnerTypes => const {installmentOwnerType};

  @override
  Future<Map<String, BusinessActivityItem>> findItems(
    Iterable<TransactionReadModel> transactions,
  ) async {
    final values = transactions.toList();
    final installments = await _query.findInstallments(_ownerIds(values));
    return {
      for (final transaction in values)
        transaction.id: ?_map(
          transaction,
          installments[transaction.ownership?.ownerId],
        ),
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

  BusinessActivityItem? _map(
    TransactionReadModel transaction,
    InstallmentDTO? installment,
  ) {
    final ownership = transaction.ownership;
    if (ownership == null || installment == null) return null;
    final factKind = resolveInstallmentTransactionFactKind(
      installmentType: installment.installmentType,
      businessPurpose: transaction.businessPurpose,
    );
    if (factKind == null) return null;
    return InstallmentBusinessActivityItem(
      activityKey: BusinessActivityKey(
        type: ownership.ownerType,
        id: ownership.ownerId,
      ),
      transactionId: transaction.id,
      installmentType: installment.installmentType,
      factKind: factKind,
    );
  }
}
