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
    this.remainingPrincipal,
    this.status,
    this.stageLabel,
    this.recalculated = false,
  });
  final String id;
  final int periodNo;
  final DateTime date;
  final Money principal, interest, fee;
  final Money? remainingPrincipal;
  final InstallmentScheduleStatus? status;
  final String? stageLabel;
  final bool recalculated;
  Money get total => principal + interest + fee;
}

List<InstallmentScheduleViewItem> calculationScheduleItems(
  List<LoanCalculationPeriod> periods, {
  List<LoanCalculationStage> stages = const [],
  int? firstRecalculatedPeriodNo,
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
        remainingPrincipal: period.remainingPrincipal,
        stageLabel: stages.length > 1 && starts.containsKey(period.periodNo)
            ? '阶段 ${starts[period.periodNo]!.index + 1}'
            : null,
        recalculated:
            firstRecalculatedPeriodNo != null &&
            period.periodNo >= firstRecalculatedPeriodNo,
      ),
  ];
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
