import 'package:flutter/material.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../core/money/money.dart';
import '../../../design_system/widget/app_detail_summary_card.dart';
import '../../../design_system/widget/app_status_badge.dart';
import '../presentation/loan_calculator_presentation.dart';

class InstallmentPlanSummaryCard extends StatelessWidget {
  const InstallmentPlanSummaryCard({
    required this.metrics,
    this.title = '还款计划',
    this.principal,
    this.periodCount,
    this.stages = const [],
    super.key,
  });

  final ContractMetrics metrics;
  final String title;
  final Money? principal;
  final int? periodCount;
  final List<LoanCalculationStage> stages;

  @override
  Widget build(BuildContext context) => AppDetailSummaryCard(
    title: title,
    headerTrailing: periodCount == null
        ? null
        : AppStatusBadge(
            label: '$periodCount 期',
            color: Theme.of(context).colorScheme.primary,
          ),
    mainItems: [
      AppDetailSummaryCardItem(
        label: '总还款',
        value: metrics.totalRepayment.format(),
      ),
      AppDetailSummaryCardItem(
        label: '总利息',
        value: metrics.totalInterest.format(),
      ),
      AppDetailSummaryCardItem(label: '总手续费', value: metrics.totalFee.format()),
    ],
    supportingItems: [
      if (principal case final amount?)
        AppDetailSummaryCardItem(label: '本金', value: amount.format()),
      if (metrics.isAvailable) ...[
        AppDetailSummaryCardItem(
          label: '月 IRR',
          value: formatRatePercent(metrics.monthlyIrr, fractionDigits: 4),
        ),
        AppDetailSummaryCardItem(
          label: '名义年化 APR',
          value: formatRatePercent(metrics.nominalApr),
        ),
        AppDetailSummaryCardItem(
          label: '有效年化 EAR',
          value: formatRatePercent(metrics.effectiveApr),
        ),
      ] else
        AppDetailSummaryCardItem(
          label: '指标不可用',
          value: contractMetricsUnavailableLabel(metrics.unavailableReason!),
          span: 2,
        ),
      for (final stage in stages)
        if (stage.installmentAmount case final amount?) ...[
          AppDetailSummaryCardItem(
            label: '第 ${stage.firstPeriodNo}–${stage.lastPeriodNo} 期固定额',
            value: amount.format(),
          ),
          if (stage.lastPeriodDifference case final difference?)
            AppDetailSummaryCardItem(
              label: '末期与固定额差额',
              value: formatSignedMoney(difference),
            ),
        ],
    ],
  );
}
