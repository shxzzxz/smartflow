import '../../../core/money/money.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/patch/patch.dart';
import '../../../core/time/date_label.dart';
import '../valobj/bill_enums.dart';
import '../valobj/credit_error_code.dart';
import '../valobj/installment_enums.dart';
import '../valobj/installment_contract_terms.dart';
import '../valobj/installment_plan_terms.dart';
import '../valobj/installment_plan_change.dart';
import '../service/settlement/settlement_judgement_service.dart';
import 'installment_schedule.dart';
import 'installment_repricing.dart';
import 'installment_repricing_configuration.dart';
import 'installment_interest_adjustment.dart';

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
    required this.installmentType,
    this.sourceRefId,
    required this.principal,
    required this.borrowingDate,
    required InstallmentContractStatus status,
    required this.createdAt,
    this.note,
    required InstallmentContractTerms stageTerms,
    List<InstallmentSchedule> schedules = const [],
    List<InstallmentRepricingConfiguration> repricingConfigurations = const [],
    List<InstallmentRepricing> repricings = const [],
    this.interestAdjustments = const [],
  }) : name = name ?? formatCompactDate(borrowingDate),
       _status = status,
       _stageTerms = stageTerms,
       _schedules = List.unmodifiable(schedules),
       _repricingConfigurations = List.unmodifiable(repricingConfigurations),
       _repricings = List.unmodifiable(repricings) {
    final reference = sourceRefId;
    final normalizedSource = reference == null || reference.trim().isEmpty
        ? null
        : reference;
    if (sourceRefId != null && normalizedSource == null ||
        installmentType != InstallmentType.disbursement &&
            normalizedSource == null) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '账单分期和消费分期必须关联来源事实',
      );
    }
    _validateSchedules(_schedules);
  }

  final String id;
  String name;
  final String liabilityAccountId;
  final InstallmentType installmentType;
  final String? sourceRefId;
  final Money principal;

  /// 本笔贷款起算日；仅在合同创建时确定。
  final DateTime borrowingDate;

  InstallmentContractStatus _status;
  String? note;
  final DateTime createdAt;
  List<InstallmentRepricingConfiguration> _repricingConfigurations;
  List<InstallmentRepricingConfiguration> get repricingConfigurations =>
      _repricingConfigurations;
  List<InstallmentRepricing> _repricings;
  List<InstallmentRepricing> get repricings => _repricings;
  final List<InstallmentInterestAdjustment> interestAdjustments;
  InstallmentContractTerms _stageTerms;
  InstallmentContractTerms get stageTerms => _stageTerms;
  List<InstallmentSchedule> _schedules;

  /// This contract's complete repayment plan.
  List<InstallmentSchedule> get schedules => _schedules;

  void reviseStageTerms(InstallmentContractTerms terms) {
    terms.validate();
    final previousEnds = {
      for (final config in _repricingConfigurations)
        config.stageId: _stageTerms
            .repaymentRange(config.stageId, borrowingDate)
            .end,
    };
    _stageTerms = terms;
    final retained = {
      for (final stage in terms.stages)
        if (stage.terms is AmortizingStage) stage.id,
    };
    _repricingConfigurations = List.unmodifiable([
      for (final config in _repricingConfigurations)
        if (retained.contains(config.stageId))
          previousEnds[config.stageId] !=
                  terms.repaymentRange(config.stageId, borrowingDate).end
              ? config.withGenerationCompleted(false)
              : config,
    ]);
    _repricings = List.unmodifiable(
      _repricings.where((record) => retained.contains(record.stageId)),
    );
  }

  InstallmentContractStatus get status => _status;

  void reviseDetails({String? name, Patch<String>? note}) {
    if (name != null) {
      if (name.trim().isEmpty) {
        throw BusinessException(
          CreditErrorCode.contractInvalidCommand,
          message: '请输入合同名称',
        );
      }
      this.name = name.trim();
    }
    if (note != null) {
      this.note = switch (note) {
        PatchSet<String>(:final value) => value,
        PatchClear<String>() => null,
      };
    }
  }

  void markSchedulePaid(String scheduleId) {
    final schedule = _requireSchedule(scheduleId);
    schedule.markPaid();
    refreshStatusFromSchedules();
  }

  void skipSchedule(String scheduleId) {
    ensureEditable();
    final schedule = _requireSchedule(scheduleId);
    schedule.skip();
    refreshStatusFromSchedules();
  }

  void restoreSchedule(String scheduleId) {
    final schedule = _requireSchedule(scheduleId);
    schedule.restore();
    refreshStatusFromSchedules();
  }

  void reviseSchedules({required List<InstallmentScheduleRevision> revisions}) {
    final byPeriod = {
      for (final schedule in _schedules) schedule.periodNo: schedule,
    };
    for (final revision in revisions) {
      final target = byPeriod[revision.periodNo];
      if (target == null) {
        throw BusinessException(
          CreditErrorCode.scheduleNotFound,
          message: 'Schedule period does not belong to the contract.',
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

  /// Applies schedule status projections supplied by bill facts.
  ///
  /// Schedules outside this aggregate are ignored; callers cannot replace or
  /// mutate plans that belong to another contract.
  void applyBillItemStatuses(Map<String, BillItemStatus> statuses) {
    final scheduleIds = _schedules.map((schedule) => schedule.id).toSet();
    for (final entry in statuses.entries) {
      if (!scheduleIds.contains(entry.key)) continue;
      _requireSchedule(entry.key).applyBillItemStatus(entry.value);
    }
    refreshStatusFromSchedules();
  }

  bool reconcileScheduleRepaymentStatus(
    String scheduleId, {
    required int allocatedPrincipalMinor,
    required bool hasAllocation,
  }) {
    return _requireSchedule(scheduleId).reconcileRepaymentStatus(
      allocatedPrincipalMinor: allocatedPrincipalMinor,
      hasAllocation: hasAllocation,
    );
  }

  void refreshStatusFromSchedules() {
    _status = _settlement.projectContractStatus(
      current: _status,
      scheduleStatuses: _schedules.map((schedule) => schedule.status),
    );
  }

  void refreshStatusFromPrincipal({required bool hasRemainingPrincipal}) {
    _status = hasRemainingPrincipal
        ? InstallmentContractStatus.active
        : InstallmentContractStatus.settled;
  }

  /// 自动计算与人工编辑分别应用，避免自动重算被标记为人工调整。
  void applyPlanChange(
    InstallmentPlanChangeSet change, {
    required String Function() newId,
    required DateTime createdAt,
  }) {
    final current = {for (final row in _schedules) row.id: row};
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
          manuallyAdjusted: row.manuallyAdjusted,
          createdAt: previous?.createdAt ?? createdAt,
          note: previous?.note,
        ),
      );
    }
    _validateSchedules(result);
    reviseStageTerms(
      InstallmentContractTerms(
        dayCount: change.terms.dayCount,
        rounding: change.terms.rounding,
        stages: [
          for (final stage in change.terms.stages)
            InstallmentContractStage(
              id: stageIds[stage.id]!,
              terms: stage.terms,
            ),
        ],
      ),
    );
    _schedules = List.unmodifiable(result);
    refreshStatusFromSchedules();
  }

  InstallmentSchedule _requireSchedule(String scheduleId) {
    for (final schedule in _schedules) {
      if (schedule.id == scheduleId) return schedule;
    }
    throw BusinessException(
      CreditErrorCode.scheduleNotFound,
      message: 'Schedule does not belong to the contract.',
    );
  }

  void _validateSchedules(List<InstallmentSchedule> schedules) {
    final ids = <String>{};
    final periods = <int>{};
    for (final schedule in schedules) {
      if (schedule.contractId != id) {
        throw BusinessException(
          CreditErrorCode.scheduleNotFound,
          message: 'Schedule does not belong to the contract.',
        );
      }
      if (!ids.add(schedule.id) || !periods.add(schedule.periodNo)) {
        throw BusinessException(
          CreditErrorCode.contractInvalidCommand,
          message: '合同还款计划包含重复身份或期次',
        );
      }
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
