import 'package:decimal/decimal.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../core/money/money.dart';
import '../../../core/time/date_label.dart';
import '../../../domain/credit/valobj/reference_rate.dart';
import '../view_model/loan_change_state.dart';
import 'installment_schedule_presentation.dart';
import 'loan_calculator_presentation.dart';
import 'loan_comparison_presentation.dart';

String loanChangeOperationLabel(LoanChangeOperationKind kind) => switch (kind) {
  LoanChangeOperationKind.prepayment => '提前还款',
  LoanChangeOperationKind.repricing => '重定价',
  LoanChangeOperationKind.interestAdjustment => '利息调整',
};

String formatLoanChangePercent(int ppm) =>
    (Decimal.fromInt(ppm) * Decimal.parse('0.0001')).toString();

String? validateLoanChangePercent(String? text, {String label = '利息比例'}) {
  final value = Decimal.tryParse(text?.trim() ?? '');
  if (value == null || value < Decimal.zero) return '请输入非负$label';
  final scaled = value * Decimal.fromInt(10000);
  return scaled == scaled.round() ? null : '$label最多保留四位小数';
}

String loanChangeOperationDescription(
  LoanChangeOperation operation,
  LoanChangeState state,
) {
  switch (operation) {
    case LoanPrepaymentOperation(:final reduction):
      return '${formatDateLabel(reduction.date)} · 提前还本金 ${reduction.principal.format()}';
    case LoanRepricingOperation(:final stageId, :final change):
      final index =
          state.configuration?.terms.stages.indexWhere(
            (stage) => stage.id == stageId,
          ) ??
          -1;
      final stage = index < 0 ? '所属阶段已移除' : '阶段 ${index + 1}';
      return '${formatDateLabel(change.effectiveDate)} 生效 · $stage\n'
          '执行年利率 ${formatLoanChangePercent(change.rate.ppm)}%';
    case LoanInterestAdjustmentOperation(:final adjustment):
      return '${formatDateLabel(adjustment.start)} 至 ${formatDateLabel(adjustment.end)}\n'
          '原利息的 ${formatLoanChangePercent(adjustment.ratioPpm)}%（不含开始日）';
  }
}

List<LoanComparisonRowPresentation> presentLoanChangeComparison(
  LoanChangeSimulation simulation,
) {
  LoanComparisonRowPresentation row(String label, Money before, Money after) =>
      LoanComparisonRowPresentation(
        label: label,
        firstValue: before.format(),
        secondValue: after.format(),
        difference: formatSignedMoney(after - before),
      );
  return [
    row('总还款', simulation.original.totalRepayment, simulation.totalRepayment),
    row('总利息', simulation.original.totalInterest, simulation.totalInterest),
    row('总手续费', simulation.original.totalFee, simulation.totalFee),
    row('息费合计', simulation.beforeCharges, simulation.afterCharges),
  ];
}

List<InstallmentScheduleViewItem> loanChangeScheduleItems(
  LoanChangeSimulation simulation,
) {
  final originals = {
    for (final period in simulation.original.periods) period.periodNo: period,
  };
  final starts = {
    for (final stage in simulation.stages) stage.firstPeriodNo: stage,
  };
  final operations = simulation.operations;
  final items = <InstallmentScheduleViewItem>[
    for (final period in simulation.periods)
      InstallmentScheduleViewItem(
        id: 'change-period-${period.periodNo}',
        periodNo: period.periodNo,
        date: period.date,
        principal: period.principal,
        interest: period.interest,
        fee: period.fee,
        statusLabel: _periodChanged(originals[period.periodNo], period)
            ? '有变化'
            : null,
        stageLabel:
            simulation.stages.length > 1 && starts.containsKey(period.periodNo)
            ? '阶段 ${starts[period.periodNo]!.index + 1}'
            : null,
      ),
    for (var i = 0; i < operations.principalReductions.length; i++)
      InstallmentScheduleViewItem(
        id: 'change-prepayment-$i',
        periodNo: 0,
        periodLabel: '提',
        date: operations.principalReductions[i].date,
        principal: operations.principalReductions[i].principal,
        interest: Money.zero(),
        fee: Money.zero(),
        statusLabel: '提前还款',
      ),
    for (final entry in operations.rateChangesByStage.entries)
      for (var i = 0; i < entry.value.length; i++)
        InstallmentScheduleViewItem(
          id: 'change-repricing-${entry.key}-$i',
          periodNo: 0,
          periodLabel: '调',
          date: entry.value[i].effectiveDate,
          principal: Money.zero(),
          interest: Money.zero(),
          fee: Money.zero(),
          detailsLabel: '阶段 ${entry.key + 1} · 执行年利率',
          amountLabel: '${formatLoanChangePercent(entry.value[i].rate.ppm)}%',
          statusLabel: '重定价',
        ),
    for (var i = 0; i < operations.interestAdjustments.length; i++)
      InstallmentScheduleViewItem(
        id: 'change-interest-adjustment-$i',
        periodNo: 0,
        periodLabel: '息',
        date: operations.interestAdjustments[i].accrualRange.start,
        principal: Money.zero(),
        interest: Money.zero(),
        fee: Money.zero(),
        detailsLabel:
            '至 ${formatDateLabel(operations.interestAdjustments[i].end)} · 原利息比例',
        amountLabel:
            '${formatLoanChangePercent(operations.interestAdjustments[i].ratioPpm)}%',
        statusLabel: '利息调整',
      ),
  ];
  items.sort((a, b) {
    final dateOrder = referenceDate(a.date).compareTo(referenceDate(b.date));
    if (dateOrder != 0) return dateOrder;
    // 同日操作先于还款行展示；当日提前还本金已计入还款后的剩余本金。
    final periodOrder = a.periodNo.compareTo(b.periodNo);
    return periodOrder != 0 ? periodOrder : a.id.compareTo(b.id);
  });
  return items;
}

bool _periodChanged(
  LoanCalculationPeriod? before,
  LoanCalculationPeriod after,
) =>
    before == null ||
    before.date != after.date ||
    before.principal != after.principal ||
    before.interest != after.interest ||
    before.fee != after.fee ||
    before.remainingPrincipal != after.remainingPrincipal;
