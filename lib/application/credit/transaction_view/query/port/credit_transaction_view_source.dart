import '../credit_transaction_view_read_models.dart';

/// Drift-backed read port owned by the credit application query.
abstract interface class CreditTransactionViewSource {
  Future<CreditTransactionViewAnchorPage> findAnchorPage(
    CreditTransactionViewQuery query,
  );

  Stream<CreditTransactionViewAnchorPage> watchAnchorPage(
    CreditTransactionViewQuery query,
  );

  Future<Map<String, CreditInstallmentSummarySource>>
  findInstallmentSummarySources(Set<String> contractIds);

  Future<Map<String, CreditRepaymentBusinessItemSummary>>
  findRepaymentSummaries(Set<String> repaymentIds);
}
