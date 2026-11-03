import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money_formatter.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';
import 'package:smartflow/widget/business/finance/finance_tone.dart';

import '../transaction_badge_presentation.dart';
import 'business_scene_presentation.dart';

BusinessItemRowContent presentAmortizationBusinessItemRow(
  BusinessItemReadModel item,
) {
  final summary = item.summary as AmortizationBusinessItemSummary;
  final isTerminated = summary.status == AmortizationStatus.terminated;
  return BusinessItemRowContent(
    preferCategoryArtwork:
        item.anchorTransaction.categoryLines.isNotEmpty ||
        summary.categoryAccountIds.isNotEmpty,
    categoryAccountIds: summary.categoryAccountIds,
    standardSummary: _standardSummary(summary),
    standardBadges: [if (isTerminated) _terminatedBadge],
    compactBadges: [
      TransactionBadgePresentation(
        label: '摊销 ${summary.postedPeriodCount}/${summary.totalPeriodCount}',
        tone: FinanceTone.neutral,
      ),
      if (isTerminated) _terminatedBadge,
    ],
  );
}

String _standardSummary(AmortizationBusinessItemSummary summary) {
  final kindLabel = switch (summary.kind) {
    AmortizationKind.prepaidExpense => '摊销预付',
    AmortizationKind.deferredIncome => '摊销预收',
  };
  return switch (summary.status) {
    AmortizationStatus.active =>
      '$kindLabel · 已确认 ${summary.postedPeriodCount}/'
          '${summary.totalPeriodCount} · '
          '待摊 ${formatMoney(summary.remainingAmount, style: MoneyFormatStyle.compact)}',
    AmortizationStatus.completed =>
      '$kindLabel · 已完成 · ${summary.totalPeriodCount}/'
          '${summary.totalPeriodCount}',
    AmortizationStatus.terminated =>
      '$kindLabel · 已确认 ${summary.postedPeriodCount}/'
          '${summary.totalPeriodCount}',
  };
}

const _terminatedBadge = TransactionBadgePresentation(
  label: '已终止',
  tone: FinanceTone.equity,
);
