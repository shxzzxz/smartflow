import '../../../core/money/money.dart';
import '../entity/installment_contract.dart';
import '../entity/installment_repricing.dart';
import '../entity/installment_schedule.dart';
import 'installment_contract_terms.dart';
import 'installment_enums.dart';

/// 一次计算的不可变事实快照；条款包含已应用的重定价事实。
class InstallmentPlanContext {
  InstallmentPlanContext({
    required this.terms,
    required this.principal,
    required this.borrowingDate,
    required List<InstallmentPlanRow> rows,
    required this.prepaymentPrincipal,
  }) : rows = List.unmodifiable(rows);

  factory InstallmentPlanContext.fromContract({
    required InstallmentContract contract,
    required List<InstallmentSchedule> schedules,
    required Money prepaymentPrincipal,
  }) => InstallmentPlanContext(
    terms: contract.stageTerms,
    principal: contract.principal,
    borrowingDate: contract.borrowingDate,
    rows: [for (final row in schedules) InstallmentPlanRow.fromSchedule(row)],
    prepaymentPrincipal: prepaymentPrincipal,
  );

  final InstallmentContractTerms terms;
  final Money principal;
  final DateTime borrowingDate;
  final List<InstallmentPlanRow> rows;
  final Money prepaymentPrincipal;
}

sealed class InstallmentPlanChangeRequest {
  const InstallmentPlanChangeRequest();
}

final class RecalculateFromTerms extends InstallmentPlanChangeRequest {
  const RecalculateFromTerms(this.terms);
  final InstallmentContractTerms terms;
}

final class ApplyInstallmentRepricing extends InstallmentPlanChangeRequest {
  const ApplyInstallmentRepricing(this.record);
  final InstallmentRepricing record;
}

final class RecalculateAfterPrepayment extends InstallmentPlanChangeRequest {
  const RecalculateAfterPrepayment(this.repaymentDate);
  final DateTime repaymentDate;
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
  bool get isPending => status == InstallmentScheduleStatus.pending;

  bool sameExpectation(InstallmentPlanRow other) =>
      stageId == other.stageId &&
      periodNo == other.periodNo &&
      date == other.date &&
      principal == other.principal &&
      interest == other.interest &&
      fee == other.fee;
}

class InstallmentPlanChangeSet {
  InstallmentPlanChangeSet({
    required this.context,
    required this.request,
    required this.terms,
    required List<InstallmentPlanRow> rows,
    required Set<String> frozenIds,
    required Set<int> recalculatedPeriods,
  }) : rows = List.unmodifiable(rows),
       frozenIds = Set.unmodifiable(frozenIds),
       recalculatedPeriods = Set.unmodifiable(recalculatedPeriods);

  final InstallmentPlanContext context;
  final InstallmentPlanChangeRequest request;
  final InstallmentContractTerms terms;
  final List<InstallmentPlanRow> rows;
  final Set<String> frozenIds;
  final Set<int> recalculatedPeriods;

  List<InstallmentPlanRow> get recalculatedRows =>
      rows.where((r) => recalculatedPeriods.contains(r.periodNo)).toList();
  List<InstallmentPlanRow> get added =>
      rows.where((r) => r.id == null).toList();
  List<InstallmentPlanRow> get removed {
    final retained = rows.map((r) => r.id).toSet();
    return context.rows.where((r) => !retained.contains(r.id)).toList();
  }

  List<InstallmentPlanRow> get updated {
    final previous = {for (final r in context.rows) r.id: r};
    return rows
        .where(
          (r) =>
              r.id != null &&
              previous[r.id] != null &&
              !r.sameExpectation(previous[r.id]!),
        )
        .toList();
  }
}
