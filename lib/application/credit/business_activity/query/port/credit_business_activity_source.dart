import '../credit_business_activity_read_models.dart';

/// Drift-backed read port owned by the credit application query.
abstract interface class CreditBusinessActivitySource {
  Future<CreditBusinessActivityAnchorPage> findAnchorPage(
    CreditBusinessActivityQuery query,
  );

  Stream<CreditBusinessActivityAnchorPage> watchAnchorPage(
    CreditBusinessActivityQuery query,
  );

  Future<Map<String, CreditRepaymentBusinessActivitySummary>>
  findRepaymentSummaries(Set<String> repaymentIds);
}
