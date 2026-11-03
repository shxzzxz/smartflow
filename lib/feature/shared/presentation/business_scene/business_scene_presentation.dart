import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';

import '../transaction_badge_presentation.dart';

enum BusinessSceneKind { ledger, advance, installment, repayment, amortization }

BusinessSceneKind businessSceneKindForBusinessActivity(
  BusinessActivityReadModel item,
) {
  return switch (item.summary) {
    LedgerBusinessActivitySummary() => BusinessSceneKind.ledger,
    AdvanceBusinessActivitySummary() => BusinessSceneKind.advance,
    InstallmentBusinessActivitySummary() => BusinessSceneKind.installment,
    RepaymentBusinessActivitySummary() => BusinessSceneKind.repayment,
    AmortizationBusinessActivitySummary() => BusinessSceneKind.amortization,
  };
}

BusinessSceneKind businessSceneKindForDetail(TransactionDetailContext context) {
  return switch (context.owner) {
    AdvanceTransactionDetailOwnerContext() => BusinessSceneKind.advance,
    InstallmentTransactionDetailOwnerContext() => BusinessSceneKind.installment,
    RepaymentTransactionDetailOwnerContext() => BusinessSceneKind.repayment,
    AmortizationTransactionDetailOwnerContext() =>
      BusinessSceneKind.amortization,
    _ => BusinessSceneKind.ledger,
  };
}

class BusinessActivityRowContent {
  const BusinessActivityRowContent({
    this.titleOverride,
    this.preferCategoryArtwork = false,
    this.categoryAccountIds = const [],
    this.standardSummary,
    this.standardBadges = const [],
    this.compactBadges = const [],
  });

  final String? titleOverride;
  final bool preferCategoryArtwork;
  final List<String> categoryAccountIds;
  final String? standardSummary;
  final List<TransactionBadgePresentation> standardBadges;
  final List<TransactionBadgePresentation> compactBadges;
}
