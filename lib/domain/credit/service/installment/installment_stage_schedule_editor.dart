import '../../../../core/error/app_exception.dart';
import '../../entity/installment_contract.dart';
import '../../entity/installment_schedule.dart';
import '../../valobj/credit_error_code.dart';
import '../../valobj/installment_contract_terms.dart';
import '../../valobj/installment_enums.dart';
import '../../valobj/installment_plan_terms.dart';
import 'installment_plan_engine.dart';
import 'installment_prepayment_recalculator.dart';

/// 显式按阶段条款重建计划，保留冻结前缀及仍存在期次的身份。
class InstallmentStageScheduleEditor {
  const InstallmentStageScheduleEditor();

  bool sameLayout(InstallmentContractTerms a, InstallmentContractTerms b) {
    if (a.stages.length != b.stages.length) return false;
    for (var i = 0; i < a.stages.length; i++) {
      final left = a.stages[i], right = b.stages[i];
      if (left.id != right.id ||
          left.terms.runtimeType != right.terms.runtimeType) {
        return false;
      }
      if (left.terms is AmortizingStage &&
          (left.terms as AmortizingStage).dates.getDates().length !=
              (right.terms as AmortizingStage).dates.getDates().length) {
        return false;
      }
    }
    return true;
  }

  void validateRevision(
    InstallmentContract contract,
    InstallmentContractTerms terms,
    List<InstallmentSchedule> schedules,
  ) {
    terms.validate();
    final ids = terms.stages.map((s) => s.id).toSet();
    final frozenEnd = _frozenEnd(schedules);
    final stagesByPeriod = _stageIds(terms);
    for (final row in schedules) {
      if (frozenEnd != null && !row.expectedRepaymentDate.isAfter(frozenEnd)) {
        final id = row.stageId ?? '${contract.id}:stage:1';
        if (!ids.contains(id) || stagesByPeriod[row.periodNo] != id) {
          throw BusinessException(
            CreditErrorCode.contractInvalidCommand,
            message: '阶段结构调整不能移除或移动已冻结期次',
          );
        }
      }
    }
  }

  List<InstallmentSchedule> rebuild({
    required InstallmentContract contract,
    required List<InstallmentSchedule> existing,
    required int prepaymentMinor,
    required String Function() newId,
  }) {
    final terms = contract.stageTerms;
    validateRevision(contract, terms, existing);
    final plan = const InstallmentPlanEngine().plan(
      terms.planTerms(contract.principal, contract.borrowingDate),
    );
    final ids = _stageIds(terms);
    final frozenEnd = _frozenEnd(existing);
    final oldByPeriod = {for (final row in existing) row.periodNo: row};
    final rows = <InstallmentSchedule>[];
    for (final entry in plan.entries) {
      final old = oldByPeriod[entry.periodNo];
      final frozen =
          old != null &&
          frozenEnd != null &&
          !old.expectedRepaymentDate.isAfter(frozenEnd);
      if (frozen) {
        rows.add(old);
      } else {
        rows.add(
          InstallmentSchedule(
            id:
                old != null &&
                    (old.stageId ?? '${contract.id}:stage:1') ==
                        ids[entry.periodNo]
                ? old.id
                : newId(),
            contractId: contract.id,
            stageId: ids[entry.periodNo],
            periodNo: entry.periodNo,
            expectedRepaymentDate: entry.expectedRepaymentDate,
            expectedPrincipal: entry.expectedPrincipal,
            expectedInterest: entry.expectedInterest,
            expectedFee: entry.expectedFee,
            status: InstallmentScheduleStatus.pending,
            createdAt: old?.createdAt ?? DateTime.now(),
            note: old?.note,
          ),
        );
      }
    }
    final updates = const InstallmentPrepaymentRecalculator().recalculate(
      contract: contract,
      schedules: rows,
      prepaymentPrincipalMinor: prepaymentMinor,
    );
    final byId = {for (final row in rows) row.id: row};
    for (final update in updates) {
      byId[update.scheduleId]!.reviseExpectation(
        expectedPrincipal: update.expectedPrincipal,
        expectedInterest: update.expectedInterest,
        expectedFee: update.expectedFee,
      );
    }
    return rows;
  }

  DateTime? _frozenEnd(List<InstallmentSchedule> rows) {
    DateTime? end;
    for (final row in rows) {
      if (row.status != InstallmentScheduleStatus.pending &&
          (end == null || row.expectedRepaymentDate.isAfter(end))) {
        end = row.expectedRepaymentDate;
      }
    }
    return end;
  }

  Map<int, String> _stageIds(InstallmentContractTerms terms) {
    final ids = <int, String>{};
    var period = 1;
    for (final stage in terms.stages) {
      if (stage.terms case AmortizingStage(:final dates)) {
        for (var i = 0; i < dates.getDates().length; i++) {
          ids[period++] = stage.id;
        }
      }
    }
    return ids;
  }
}
