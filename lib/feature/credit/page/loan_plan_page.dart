import 'package:flutter/material.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../core/time/date_label.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_detail_summary_card.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../presentation/installment_schedule_presentation.dart';
import '../widget/installment_plan_summary_card.dart';
import '../widget/installment_schedule_view.dart';

class LoanPlanPage extends StatelessWidget {
  const LoanPlanPage({required LoanCalculation this.calculation, super.key})
    : simulation = null,
      prepaymentDate = null;
  const LoanPlanPage.prepayment({
    required LoanPrepaymentSimulation this.simulation,
    required DateTime this.prepaymentDate,
    super.key,
  }) : calculation = null;

  final LoanCalculation? calculation;
  final LoanPrepaymentSimulation? simulation;
  final DateTime? prepaymentDate;

  @override
  Widget build(BuildContext context) {
    final repayment = simulation;
    final items = repayment != null
        ? prepaymentScheduleItems(repayment, prepaymentDate!)
        : calculationScheduleItems(
            calculation!.periods,
            stages: calculation!.stages,
          );
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(title: repayment == null ? '还款计划' : '提前还款结果'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.space16),
                children: [
                  if ((calculation?.isRateProjection ?? false) ||
                      (repayment?.isRateProjection ?? false)) ...[
                    const Text('浮动利率预测：尚未确定的未来利率沿用已知利率，总利息与年化成本会随重定价变化。'),
                    const SizedBox(height: AppSpacing.space12),
                  ],
                  if (repayment == null)
                    InstallmentPlanSummaryCard(
                      title: '试算概览',
                      metrics: calculation!.metrics,
                      principal: calculation!.totalPrincipal,
                      periodCount: calculation!.periods.length,
                    )
                  else
                    AppDetailSummaryCard(
                      title: '提前还款试算',
                      mainItems: [
                        AppDetailSummaryCardItem(
                          label: '试算前息费',
                          value: repayment.beforeCharges.format(),
                        ),
                        AppDetailSummaryCardItem(
                          label: '试算后息费',
                          value: repayment.afterCharges.format(),
                        ),
                        AppDetailSummaryCardItem(
                          label: '息费变化',
                          value: repayment.chargesSaved.format(),
                        ),
                      ],
                      supportingItems: [
                        AppDetailSummaryCardItem(
                          label: '提前还本金',
                          value: repayment.prepaymentPrincipal.format(),
                        ),
                        AppDetailSummaryCardItem(
                          label: '提前还款日',
                          value: formatDateLabel(prepaymentDate!),
                        ),
                      ],
                    ),
                  const SizedBox(height: AppSpacing.space16),
                  Text(
                    repayment == null ? '逐期明细' : '试算后还款计划',
                    style: context.appTextStyles.dateSectionTitle,
                  ),
                  const SizedBox(height: AppSpacing.space6),
                  InstallmentScheduleView(items: items),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
