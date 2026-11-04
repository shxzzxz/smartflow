part of 'transaction_detail_state_builder.dart';

({
  String occurredAtText,
  String postedAtText,
  String createdAtText,
  String? noteText,
  bool canEditReportingFlags,
  bool showExcludeStats,
  bool showExcludeBudget,
  bool excludeStats,
  bool excludeBudget,
})
_buildTransactionDetailShell(TransactionDetailContext context) {
  final transaction = context.transaction;
  final parentFacts = context.parentFacts;
  return (
    occurredAtText: formatTransactionDetailDateTime(transaction.occurredAt),
    postedAtText: formatTransactionDetailDateTime(transaction.postedAt),
    createdAtText: formatTransactionDetailDateTime(
      transaction.createdAt ?? transaction.occurredAt,
    ),
    noteText: transaction.note,
    canEditReportingFlags: transaction.parentTransactionId == null,
    showExcludeStats: true,
    showExcludeBudget: true,
    excludeStats:
        parentFacts?.isExcludedFromStats ?? transaction.isExcludedFromStats,
    excludeBudget:
        parentFacts?.isExcludedFromBudget ?? transaction.isExcludedFromBudget,
  );
}
