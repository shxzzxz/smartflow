import 'package:flutter/material.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../presentation/installment_schedule_presentation.dart';
import '../presentation/loan_change_presentation.dart';
import '../view_model/loan_configuration_view_model.dart';
import '../widget/installment_plan_summary_card.dart';
import '../widget/installment_schedule_view.dart';
import '../widget/loan_calculator_action_button.dart';
import '../widget/loan_comparison_table.dart';
import 'loan_comparison_page.dart';
import 'loan_change_page.dart';

class LoanPlanPage extends StatelessWidget {
  const LoanPlanPage({required LoanConfiguration this.configuration, super.key})
    : simulation = null;
  const LoanPlanPage.changes({
    required LoanChangeSimulation this.simulation,
    super.key,
  }) : configuration = null;

  final LoanConfiguration? configuration;
  final LoanChangeSimulation? simulation;

  @override
  Widget build(BuildContext context) {
    final repayment = simulation;
    final calculation = configuration?.calculation;
    final items = repayment != null
        ? loanChangeScheduleItems(repayment)
        : calculationScheduleItems(
            calculation!.periods,
            stages: calculation.stages,
          );
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: repayment == null ? '还款计划' : '贷款变更结果',
              actions: [
                if (configuration case final source?) ...[
                  LoanCalculatorActionButton.compare(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => LoanComparisonPage(initial: source),
                      ),
                    ),
                  ),
                  LoanCalculatorActionButton.change(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => LoanChangePage(initial: source),
                      ),
                    ),
                  ),
                ],
              ],
            ),
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
                      principal: calculation.totalPrincipal,
                      periodCount: calculation.periods.length,
                    )
                  else ...[
                    LoanComparisonTable(
                      rows: presentLoanChangeComparison(repayment),
                      firstLabel: '原计划',
                      secondLabel: '操作后',
                      differenceLabel: '变化',
                    ),
                    if (repayment.operations.principalReductions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.space12),
                        child: Text(
                          '提前还本金合计 ${repayment.prepaymentPrincipal.format()}，已计入总还款。',
                          style: context.appTextStyles.formSupporting,
                        ),
                      ),
                  ],
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
