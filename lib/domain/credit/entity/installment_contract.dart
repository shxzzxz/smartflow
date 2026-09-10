import '../../../core/money/money.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/patch/patch.dart';
import '../../../core/time/date_label.dart';
import '../valobj/credit_error_code.dart';
import '../valobj/installment_enums.dart';
import '../valobj/installment_contract_terms.dart';
import '../valobj/installment_plan_change.dart';
import '../service/settlement/settlement_judgement_service.dart';
import 'installment_schedule.dart';

class InstallmentScheduleRevision {
  const InstallmentScheduleRevision({
    required this.periodNo,
    this.expectedPrincipal,
    this.expectedInterest,
    this.expectedFee,
    this.expectedRepaymentDate,
  });

  final int periodNo;
  final Money? expectedPrincipal;
  final Money? expectedInterest;
  final Money? expectedFee;
  final DateTime? expectedRepaymentDate;
}

class InstallmentContract {
  static const _settlement = SettlementJudgementService();

  InstallmentContract({
    required this.id,
    String? name,
    required this.liabilityAccountId,
    required this.sourceType,
    required this.principal,
    required this.borrowingDate,
    required InstallmentContractStatus status,
    required this.createdAt,
    this.disbursementAccountId,
    this.disbursementTransactionId,
    this.sourceRepaymentId,
    this.note,
    required InstallmentContractTerms stageTerms,
    this.productId,
    this.productName,
    this.customRules = false,
  }) : name = name ?? formatCompactDate(borrowingDate),
       _status = status,
       _stageTerms = stageTerms;

  final String id;
  String name;
  final String liabilityAccountId;
  final InstallmentSourceType sourceType;
  String? disbursementAccountId;
  final String? disbursementTransactionId;
  final String? sourceRepaymentId;
  final Money principal;

  /// 本笔贷款起算日，可通过合同编辑同步更正放款交易日期。
  DateTime borrowingDate;

  InstallmentContractStatus _status;
  String? note;
  final DateTime createdAt;
  String? productId;
  String? productName;
  bool customRules;
  InstallmentContractTerms _stageTerms;
  InstallmentContractTerms get stageTerms => _stageTerms;

  void reviseStageTerms(
    InstallmentContractTerms terms, {
    bool? customRules,
    String? productId,
    String? productName,
  }) {
    ensureEditable();
    terms.validateReplacementOf(_stageTerms);
    _stageTerms = terms;
    if (customRules != null) this.customRules = customRules;
    if (productId != null) {
      this.productId = productId;
      this.productName = productName;
    }
  }

  InstallmentContractStatus get status => _status;

  void reviseDetails({
    String? name,
    DateTime? borrowingDate,
    Patch<String>? note,
    String? disbursementAccountId,
  }) {
    ensureEditable();
    if (name != null) {
      if (name.trim().isEmpty) {
        throw BusinessException(
          CreditErrorCode.contractInvalidCommand,
          message: '请输入合同名称',
        );
      }
      this.name = name.trim();
    }
    if (disbursementAccountId != null &&
        (sourceType != InstallmentSourceType.disbursement ||
            disbursementTransactionId == null)) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message:
            'A contract without a disbursement transaction cannot carry a disbursement account.',
      );
    }
    if (borrowingDate != null) this.borrowingDate = borrowingDate;
    if (disbursementAccountId != null) {
      this.disbursementAccountId = disbursementAccountId;
    }
    if (note != null) {
      this.note = switch (note) {
        PatchSet<String>(:final value) => value,
        PatchClear<String>() => null,
      };
    }
  }

  void markSchedulePaid(
    InstallmentSchedule schedule, {
    required List<InstallmentSchedule> schedules,
  }) {
    _ensureScheduleBelongsToContract(schedule);
    schedule.markPaid();
    refreshStatusFromSchedules(schedules);
  }

  void skipSchedule(
    InstallmentSchedule schedule, {
    required List<InstallmentSchedule> schedules,
  }) {
    ensureEditable();
    _ensureScheduleBelongsToContract(schedule);
    schedule.skip();
    refreshStatusFromSchedules(schedules);
  }

  void restoreSchedule(
    InstallmentSchedule schedule, {
    required List<InstallmentSchedule> schedules,
  }) {
    _ensureScheduleBelongsToContract(schedule);
    schedule.restore();
    refreshStatusFromSchedules(schedules);
  }

  void reviseSchedules({
    required List<InstallmentSchedule> schedules,
    required List<InstallmentScheduleRevision> revisions,
  }) {
    ensureEditable();
    for (final schedule in schedules) {
      _ensureScheduleBelongsToContract(schedule);
    }
    final byPeriod = {
      for (final schedule in schedules) schedule.periodNo: schedule,
    };
    for (final revision in revisions) {
      final target = byPeriod[revision.periodNo];
      if (target == null) {
        throw BusinessException(
          CreditErrorCode.scheduleNotFound,
          message: 'Schedule period does not belong to the contract.',
        );
      }
      if (target.status != InstallmentScheduleStatus.pending) {
        throw BusinessException(
          CreditErrorCode.scheduleNotPending,
          message: 'Only pending schedules can be edited.',
        );
      }
    }
    for (final revision in revisions) {
      final target = byPeriod[revision.periodNo]!;
      if ((revision.expectedPrincipal != null &&
              revision.expectedPrincipal != target.expectedPrincipal) ||
          (revision.expectedInterest != null &&
              revision.expectedInterest != target.expectedInterest) ||
          (revision.expectedFee != null &&
              revision.expectedFee != target.expectedFee) ||
          (revision.expectedRepaymentDate != null &&
              revision.expectedRepaymentDate != target.expectedRepaymentDate)) {
        target.manuallyAdjusted = true;
      }
      target.reviseExpectation(
        expectedPrincipal: revision.expectedPrincipal,
        expectedInterest: revision.expectedInterest,
        expectedFee: revision.expectedFee,
        expectedRepaymentDate: revision.expectedRepaymentDate,
      );
    }
  }

  void refreshStatusFromSchedules(List<InstallmentSchedule> schedules) {
    for (final schedule in schedules) {
      _ensureScheduleBelongsToContract(schedule);
    }
    _status = _settlement.projectContractStatus(
      current: _status,
      scheduleStatuses: schedules.map((schedule) => schedule.status),
    );
  }

  /// 自动计算与人工编辑分别应用，避免自动重算被标记为人工调整。
  List<InstallmentSchedule> applyPlanChange(
    InstallmentPlanChangeSet change, {
    required List<InstallmentSchedule> schedules,
    required String Function() newId,
    required DateTime createdAt,
  }) {
    ensureEditable();
    for (final schedule in schedules) {
      _ensureScheduleBelongsToContract(schedule);
    }
    final current = {for (final row in schedules) row.id: row};
    final proposed = {
      for (final row in change.rows)
        if (row.id != null) row.id: row,
    };
    for (final previous in schedules) {
      if (previous.status == InstallmentScheduleStatus.pending &&
          !change.frozenIds.contains(previous.id)) {
        continue;
      }
      final next = proposed[previous.id];
      if (next == null ||
          next.status != previous.status ||
          !next.sameExpectation(InstallmentPlanRow.fromSchedule(previous)) ||
          next.manuallyAdjusted != previous.manuallyAdjusted) {
        throw BusinessException(
          CreditErrorCode.scheduleNotPending,
          message: '计划变更不能修改或移除冻结期次',
        );
      }
    }
    final result = <InstallmentSchedule>[];
    final ownedStages = _stageTerms.stages.map((s) => s.id).toSet();
    final stageIds = {
      for (final stage in change.terms.stages)
        stage.id: ownedStages.contains(stage.id) ? stage.id : newId(),
    };
    final ids = <String>{};
    final periods = <int>{};
    for (final row in change.rows) {
      final previous = row.id == null ? null : current[row.id];
      if ((row.id != null && previous == null) ||
          !periods.add(row.periodNo) ||
          (row.id != null && !ids.add(row.id!))) {
        throw BusinessException(
          CreditErrorCode.contractInvalidCommand,
          message: '计划变更包含无效身份或重复期次',
        );
      }
      result.add(
        InstallmentSchedule(
          id: row.id ?? newId(),
          contractId: id,
          stageId: stageIds[row.stageId] ?? row.stageId,
          periodNo: row.periodNo,
          expectedRepaymentDate: row.date,
          expectedPrincipal: row.principal,
          expectedInterest: row.interest,
          expectedFee: row.fee,
          status: row.status,
          manuallyAdjusted:
              change.request is RecalculateFromTerms &&
                  change.recalculatedPeriods.contains(row.periodNo)
              ? false
              : previous?.manuallyAdjusted ?? false,
          createdAt: previous?.createdAt ?? createdAt,
          note: previous?.note,
        ),
      );
    }
    _stageTerms = InstallmentContractTerms(
      dayCount: change.terms.dayCount,
      rounding: change.terms.rounding,
      tailDifference: change.terms.tailDifference,
      stages: [
        for (final stage in change.terms.stages)
          InstallmentContractStage(id: stageIds[stage.id]!, terms: stage.terms),
      ],
    );
    refreshStatusFromSchedules(result);
    return result;
  }

  void _ensureScheduleBelongsToContract(InstallmentSchedule schedule) {
    if (schedule.contractId != id) {
      throw BusinessException(
        CreditErrorCode.scheduleNotFound,
        message: 'Schedule does not belong to the contract.',
      );
    }
  }

  void ensureEditable() {
    if (_status != InstallmentContractStatus.active) {
      throw BusinessException(
        CreditErrorCode.contractNotActive,
        message: 'Only active contracts can be edited.',
      );
    }
  }
}
