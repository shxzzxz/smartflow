import '../../../application/credit/credit_query_api.dart';
import '../../../core/money/money.dart';

/// 展示行只携带已有计划事实；合同余额不由组件推算。
class InstallmentScheduleViewItem {
  const InstallmentScheduleViewItem({
    required this.id,
    required this.periodNo,
    required this.date,
    required this.principal,
    required this.interest,
    required this.fee,
    this.status,
    this.stageLabel,
    this.periodLabel,
    this.statusLabel,
  });
  final String id;
  final int periodNo;
  final DateTime date;
  final Money principal, interest, fee;
  final InstallmentScheduleStatus? status;
  final String? stageLabel;
  final String? periodLabel;
  final String? statusLabel;
  Money get total => principal + interest + fee;
}

List<InstallmentScheduleViewItem> calculationScheduleItems(
  List<LoanCalculationPeriod> periods, {
  List<LoanCalculationStage> stages = const [],
}) {
  final starts = {for (final stage in stages) stage.firstPeriodNo: stage};
  return [
    for (final period in periods)
      InstallmentScheduleViewItem(
        id: 'calculation-${period.periodNo}',
        periodNo: period.periodNo,
        date: period.date,
        principal: period.principal,
        interest: period.interest,
        fee: period.fee,
        stageLabel: stages.length > 1 && starts.containsKey(period.periodNo)
            ? '阶段 ${starts[period.periodNo]!.index + 1}'
            : null,
      ),
  ];
}

List<InstallmentScheduleViewItem> prepaymentScheduleItems(
  LoanPrepaymentSimulation simulation,
  DateTime prepaymentDate,
) {
  final items =
      [
        for (final period in simulation.periods)
          InstallmentScheduleViewItem(
            id: 'prepayment-period-${period.periodNo}',
            periodNo: period.periodNo,
            date: period.date,
            principal: period.principal,
            interest: period.interest,
            fee: period.fee,
            statusLabel: _prepaymentStatus(simulation, period.periodNo),
            stageLabel: simulation.stages.length > 1
                ? _stageLabelFor(simulation.stages, period.periodNo)
                : null,
          ),
        InstallmentScheduleViewItem(
          id: 'prepayment-event',
          periodNo: 0,
          periodLabel: '提',
          date: prepaymentDate,
          principal: simulation.prepaymentPrincipal,
          interest: Money.zero(),
          fee: Money.zero(),
          statusLabel: '提前还',
        ),
      ]..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        // The event is shown before the regular period when dates coincide.
        if (a.periodLabel == '提') return -1;
        if (b.periodLabel == '提') return 1;
        return a.periodNo.compareTo(b.periodNo);
      });
  return items;
}

String? _prepaymentStatus(LoanPrepaymentSimulation simulation, int periodNo) {
  if (periodNo <= simulation.paidPeriods) return '已还';
  final first = simulation.firstRecalculatedPeriodNo;
  return first != null && periodNo >= first ? '重算' : '待还';
}

String? _stageLabelFor(List<LoanCalculationStage> stages, int periodNo) {
  for (final stage in stages) {
    if (periodNo == stage.firstPeriodNo) {
      return '阶段 ${stage.index + 1}';
    }
  }
  return null;
}

String installmentScheduleStatusLabel(InstallmentScheduleStatus status) =>
    switch (status) {
      InstallmentScheduleStatus.pending => '待还',
      InstallmentScheduleStatus.partiallyPaid => '部分已还',
      InstallmentScheduleStatus.paid => '已还',
      InstallmentScheduleStatus.skipped => '已跳过',
    };

List<InstallmentScheduleViewItem> contractScheduleItems(
  InstallmentContractReadModel contract,
  List<InstallmentScheduleReadModel> schedules,
) {
  final stageIndexes = {
    for (var i = 0; i < contract.stageTerms.stages.length; i++)
      contract.stageTerms.stages[i].id: i,
  };
  final seen = <String>{};
  return [
    for (final row in schedules)
      InstallmentScheduleViewItem(
        id: row.id,
        periodNo: row.periodNo,
        date: row.expectedRepaymentDate,
        principal: row.expectedPrincipal,
        interest: row.expectedInterest,
        fee: row.expectedFee,
        status: row.status,
        stageLabel:
            stageIndexes.length > 1 &&
                row.stageId != null &&
                stageIndexes.containsKey(row.stageId) &&
                seen.add(row.stageId!)
            ? '阶段 ${stageIndexes[row.stageId]! + 1}'
            : null,
      ),
  ];
}
