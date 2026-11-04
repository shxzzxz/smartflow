import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';
import 'package:smartflow/feature/transaction/presentation/transaction_detail_presentation.dart';

import 'transaction_detail_business_presentation.dart';

TransactionDetailBusinessContent presentAdvanceDetailBusinessScene(
  TransactionDetailReadModel detail,
) {
  final context = detail.context;
  final item = context.businessItem;
  final activity = detail.businessActivity;
  final summary = activity?.summary;
  if (item is! AdvanceBusinessActivityItem ||
      item.factKind != AdvanceTransactionFactKind.advance ||
      item.trackingMode != AdvanceTrackingMode.itemized ||
      summary is! AdvanceBusinessActivitySummary ||
      activity == null) {
    return const TransactionDetailBusinessContent();
  }

  final anchorTransaction = activity.anchorTransaction;
  final items = advanceSheetItems(anchorTransaction.children);
  final hasActivity = items.isNotEmpty;
  final facts = anchorTransaction.advanceSummary;
  final summaryText = summary.isClosed
      ? '已结清 · 实收 ${facts?.receivedAmount.format() ?? '0.00'}'
      : hasActivity
      ? '已收 ${facts?.receivedAmount.format() ?? '0.00'} / '
            '应收 ${facts?.advanceAmount.format() ?? '0.00'}'
      : '未收回';
  return TransactionDetailBusinessContent(
    advance: DetailAdvance(
      summaryText: summaryText,
      hasActivity: hasActivity,
      isClosed: summary.isClosed,
      outstanding: summary.outstanding,
      items: items,
    ),
  );
}
