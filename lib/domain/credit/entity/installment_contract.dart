import '../../../core/money/money.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/patch/patch.dart';
import '../valobj/credit_error_code.dart';
import '../valobj/installment_enums.dart';
import '../valobj/installment_contract_terms.dart';
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
  }) : _status = status,
       _stageTerms = stageTerms;

  final String id;
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
  final String? productId;
  final String? productName;
  bool customRules;
  InstallmentContractTerms _stageTerms;
  InstallmentContractTerms get stageTerms => _stageTerms;

  void reviseStageTerms(InstallmentContractTerms terms, {bool? customRules}) {
    ensureEditable();
    terms.validate();
    _stageTerms = terms;
    if (customRules != null) this.customRules = customRules;
  }

  InstallmentContractStatus get status => _status;

  void reviseDetails({
    DateTime? borrowingDate,
    Patch<String>? note,
    String? disbursementAccountId,
  }) {
    ensureEditable();
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
