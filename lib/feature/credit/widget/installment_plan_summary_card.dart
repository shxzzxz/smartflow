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
    this.contractStatus,
    super.key,
  });

  final ContractMetrics metrics;
  final String title;
  final Money? principal;
  final int? periodCount;
  final InstallmentContractStatus? contractStatus;

  @override
  Widget build(BuildContext context) => AppDetailSummaryCard(
    title: title,
    headerTrailing: contractStatus != null
        ? AppStatusBadge(
            label: contractStatus == InstallmentContractStatus.active
                ? '进行中'
                : '已结清',
            color: contractStatus == InstallmentContractStatus.active
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.tertiary,
          )
        : periodCount == null
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
      if (metrics.isAvailable)
        AppDetailSummaryCardItem(
          label: '实际年化（XIRR）',
          value: formatRatePercent(metrics.xirr),
        )
      else
        AppDetailSummaryCardItem(
          label: '指标不可用',
          value: contractMetricsUnavailableLabel(metrics.unavailableReason!),
          span: 2,
        ),
    ],
  );
}
