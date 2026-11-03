import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money_formatter.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/widget/business/finance/finance_tone.dart';

import '../transaction_badge_presentation.dart';
import 'business_scene_presentation.dart';

BusinessItemRowContent presentInstallmentBusinessItemRow(
  BusinessItemReadModel item,
) {
  final summary = item.summary as InstallmentBusinessItemSummary;
  final usesCategoryArtwork =
      summary.installmentType == InstallmentType.purchase ||
      summary.installmentType == InstallmentType.billConversion;
  return BusinessItemRowContent(
    titleOverride: summary.installmentType == InstallmentType.disbursement
        ? '放款分期'
        : null,
    preferCategoryArtwork:
        usesCategoryArtwork && item.anchorTransaction.categoryLines.isNotEmpty,
    standardSummary: _standardSummary(summary),
    compactBadges: summary.installmentType == InstallmentType.purchase
        ? [
            TransactionBadgePresentation(
              label:
                  '分期 ${summary.paidPeriodCount}/${summary.totalPeriodCount}',
              tone: FinanceTone.neutral,
            ),
          ]
        : const [],
  );
}

String _standardSummary(InstallmentBusinessItemSummary summary) {
  final typeLabel = switch (summary.installmentType) {
    InstallmentType.purchase => '消费分期',
    InstallmentType.disbursement => '放款分期',
    InstallmentType.billConversion => '账单分期',
  };
  if (summary.status == InstallmentContractStatus.settled) {
    return '$typeLabel · 已结清 · ${summary.totalPeriodCount}/'
        '${summary.totalPeriodCount}';
  }
  return '$typeLabel · 已还 ${summary.paidPeriodCount}/'
      '${summary.totalPeriodCount} · '
      '待还本金 ${formatMoney(summary.remainingPrincipal, style: MoneyFormatStyle.compact)}';
}
