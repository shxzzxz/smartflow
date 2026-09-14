import '../../../core/money/money.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/patch/patch.dart';
import '../../../core/time/date_label.dart';
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
    List<InstallmentRepricingConfiguration> repricingConfigurations = const [],
    List<InstallmentRepricing> repricings = const [],
    this.interestAdjustments = const [],
  }) : name = name ?? formatCompactDate(borrowingDate),
       _status = status,
       _stageTerms = stageTerms,
       _repricingConfigurations = List.unmodifiable(repricingConfigurations),
       _repricings = List.unmodifiable(repricings);

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
  List<InstallmentRepricingConfiguration> _repricingConfigurations;
  List<InstallmentRepricingConfiguration> get repricingConfigurations =>
      _repricingConfigurations;
  List<InstallmentRepricing> _repricings;
  List<InstallmentRepricing> get repricings => _repricings;
  final List<InstallmentInterestAdjustment> interestAdjustments;
  InstallmentContractTerms _stageTerms;
  InstallmentContractTerms get stageTerms => _stageTerms;

  void reviseStageTerms(InstallmentContractTerms terms) {
    terms.validate();
    _stageTerms = terms;
    final retained = {
      for (final stage in terms.stages)
        if (stage.terms is AmortizingStage) stage.id,
    };
    _repricingConfigurations = List.unmodifiable(
      _repricingConfigurations.where(
        (config) => retained.contains(config.stageId),
      ),
    );
    _repricings = List.unmodifiable(
      _repricings.where((record) => retained.contains(record.stageId)),
    );
  }

  InstallmentContractStatus get status => _status;

  void reviseDetails({
    String? name,
    DateTime? borrowingDate,
    Patch<String>? note,
    String? disbursementAccountId,
  }) {
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
    for (final schedule in schedules) {
      _ensureScheduleBelongsToContract(schedule);
    }
    final current = {for (final row in schedules) row.id: row};
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
