import '../../installment/query/port/installment_statistics_change_source.dart';
import 'credit_transaction_view_read_models.dart';
import 'port/credit_transaction_view_source.dart';

/// Credit-domain query used by the cross-domain transaction view.
abstract interface class CreditTransactionViewQueryService {
  Future<CreditTransactionViewAnchorPage> findAnchorPage(
    CreditTransactionViewQuery query,
  );

  Stream<CreditTransactionViewAnchorPage> watchAnchorPage(
    CreditTransactionViewQuery query,
  );

  Future<Map<String, CreditRepaymentBusinessItemSummary>>
  findRepaymentSummaries(Set<String> repaymentIds);

  Stream<CreditRepaymentBusinessItemSummary?> watchRepaymentSummary(
    String repaymentId,
  );
}

final class CreditTransactionViewQueryServiceImpl
    implements CreditTransactionViewQueryService {
  CreditTransactionViewQueryServiceImpl({
    required CreditTransactionViewSource source,
    required InstallmentStatisticsChangeSource changes,
  }) : _source = source,
       _changes = changes;

  final CreditTransactionViewSource _source;
  final InstallmentStatisticsChangeSource _changes;

  @override
  Future<CreditTransactionViewAnchorPage> findAnchorPage(
    CreditTransactionViewQuery query,
  ) => _source.findAnchorPage(query);

  @override
  Stream<CreditTransactionViewAnchorPage> watchAnchorPage(
    CreditTransactionViewQuery query,
  ) => _source.watchAnchorPage(query);

  @override
  Future<Map<String, CreditRepaymentBusinessItemSummary>>
  findRepaymentSummaries(Set<String> repaymentIds) {
    return _source.findRepaymentSummaries(repaymentIds);
  }

  @override
  Stream<CreditRepaymentBusinessItemSummary?> watchRepaymentSummary(
    String repaymentId,
  ) {
    return _changes.watchChanges().asyncMap((_) async {
      final summaries = await findRepaymentSummaries({repaymentId});
      return summaries[repaymentId];
    });
  }
}
