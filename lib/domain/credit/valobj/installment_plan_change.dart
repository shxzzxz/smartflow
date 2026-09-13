import '../../../core/money/money.dart';
import '../entity/installment_contract.dart';
import '../entity/installment_schedule.dart';
import 'installment_contract_terms.dart';
import 'installment_enums.dart';
import 'installment_plan_operation.dart';

/// 用例预览的事实快照；旧计划只用于保存时衔接引用，不进入计算。
class InstallmentPlanContext {
  InstallmentPlanContext({
    required this.terms,
    required this.principal,
    required this.borrowingDate,
    required List<InstallmentPlanRow> rows,
    this.operations = const InstallmentPlanOperations(),
  }) : rows = List.unmodifiable(rows);

  factory InstallmentPlanContext.fromContract({
    required InstallmentContract contract,
    required List<InstallmentSchedule> schedules,
    InstallmentPlanOperations operations = const InstallmentPlanOperations(),
  }) => InstallmentPlanContext(
    terms: contract.stageTerms,
    principal: contract.principal,
    borrowingDate: contract.borrowingDate,
    rows: [for (final row in schedules) InstallmentPlanRow.fromSchedule(row)],
    operations: operations,
  );

  final InstallmentContractTerms terms;
  final Money principal;
  final DateTime borrowingDate;
  final List<InstallmentPlanRow> rows;
  final InstallmentPlanOperations operations;
}

sealed class InstallmentPlanChangeRequest {
  const InstallmentPlanChangeRequest();
}

final class RecalculateFromTerms extends InstallmentPlanChangeRequest {
  const RecalculateFromTerms(this.terms);
  final InstallmentContractTerms terms;
}

final class RecalculateFromOperations extends InstallmentPlanChangeRequest {
  const RecalculateFromOperations();
}

/// 新增期次尚无持久化身份；身份只在应用结果时分配。
class InstallmentPlanRow {
  const InstallmentPlanRow({
    required this.id,
    required this.stageId,
    required this.periodNo,
    required this.date,
    required this.principal,
    required this.interest,
    required this.fee,
    required this.status,
    this.manuallyAdjusted = false,
  });

  factory InstallmentPlanRow.fromSchedule(InstallmentSchedule row) =>
      InstallmentPlanRow(
        id: row.id,
        stageId: row.stageId,
        periodNo: row.periodNo,
        date: row.expectedRepaymentDate,
        principal: row.expectedPrincipal,
        interest: row.expectedInterest,
        fee: row.expectedFee,
        status: row.status,
        manuallyAdjusted: row.manuallyAdjusted,
      );

  final String? id;
  final String? stageId;
  final int periodNo;
  final DateTime date;
  final Money principal, interest, fee;
  final InstallmentScheduleStatus status;
  final bool manuallyAdjusted;
}

class InstallmentPlanChangeSet {
  InstallmentPlanChangeSet({
    required this.context,
    required this.terms,
    required List<InstallmentPlanRow> rows,
  }) : rows = List.unmodifiable(rows);

  final InstallmentPlanContext context;
  final InstallmentContractTerms terms;
  final List<InstallmentPlanRow> rows;
}
