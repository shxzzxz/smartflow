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
        ? calculationScheduleItems(repayment.periods, stages: repayment.stages)
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
                          label: '节省利息',
                          value: repayment.interestSaved.format(),
                        ),
                        AppDetailSummaryCardItem(
                          label: '试算后总利息',
                          value: repayment.totalInterest.format(),
                        ),
                        AppDetailSummaryCardItem(
                          label: '总手续费',
                          value: repayment.totalFee.format(),
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
                        AppDetailSummaryCardItem(
                          label: '重算范围',
                          span: 2,
                          value: repayment.firstRecalculatedPeriodNo == null
                              ? '剩余本金已结清，无待还期次'
                              : '第 ${repayment.firstRecalculatedPeriodNo} 期起',
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
