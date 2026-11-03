import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';
import 'package:smartflow/feature/transaction/presentation/transaction_detail_presentation.dart';

import 'transaction_detail_business_presentation.dart';

TransactionDetailBusinessContent presentAdvanceDetailBusinessScene(
  TransactionDetailContext context,
) {
  final owner = context.owner;
  if (owner is! AdvanceTransactionDetailOwnerContext ||
      context.transaction.businessPurpose != BusinessPurpose.advance ||
      owner.trackingMode != AdvanceTrackingMode.itemized) {
    return const TransactionDetailBusinessContent();
  }

  final items = advanceSheetItems(context.transaction.children);
  final hasActivity = items.isNotEmpty;
  final summaryText = owner.isClosed
      ? '已结清 · 实收 ${owner.receivedAmount.format()}'
      : hasActivity
      ? '已收 ${owner.receivedAmount.format()} / 应收 ${owner.advanceAmount.format()}'
      : '未收回';
  return TransactionDetailBusinessContent(
    advance: DetailAdvance(
      summaryText: summaryText,
      hasActivity: hasActivity,
      isClosed: owner.isClosed,
      outstanding: owner.outstanding,
      items: items,
    ),
  );
}
