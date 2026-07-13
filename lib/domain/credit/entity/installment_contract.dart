import '../../../core/money/money.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/patch/patch.dart';
import '../valobj/credit_error_code.dart';
import '../valobj/installment_enums.dart';
import '../service/settlement/settlement_judgement_service.dart';
import '../service/installment/installment_financial_terms_policy.dart';
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
  static const _financialTerms = InstallmentFinancialTermsPolicy();

  InstallmentContract({
    required this.id,
    required this.liabilityAccountId,
    required this.sourceType,
    required this.principal,
    required this.totalPeriods,
    required this.borrowingDate,
    required this.firstRepaymentDate,
    required this.lastRepaymentDate,
    required this.repaymentMethod,
    required this.interestAccrualMethod,
    required this.totalFeeMinor,
    required InstallmentContractStatus status,
    required this.createdAt,
    this.disbursementAccountId,
    this.disbursementTransactionId,
    this.sourceRepaymentId,
    this.interestRatePeriod,
    this.interestRatePpm,
    this.note,
  }) : _status = status;

  final String id;
  final String liabilityAccountId;
  final InstallmentSourceType sourceType;
  String? disbursementAccountId;
  final String? disbursementTransactionId;
  final String? sourceRepaymentId;
  final Money principal;
  int totalPeriods;

  /// 借款日期（放款分期 = 放款交易日；账单分期 = 合同起算日）。
  /// 决定第一期利息天数计算的起点，创建后不可变更。
  DateTime borrowingDate;

  /// 首期还款日。
  DateTime firstRepaymentDate;

  /// 末期还款日。默认 = 首期 + (totalPeriods - 1) 月，可独立调整。
  DateTime lastRepaymentDate;

  InstallmentRepaymentMethod repaymentMethod;
  InterestRatePeriod? interestRatePeriod;
  int? interestRatePpm;

  /// 计息方式（按日 / 按月）。决定还款计划的利息计算口径。
  InterestAccrualMethod interestAccrualMethod;

  /// 合同的总手续费（minor units），用于编辑时按 method 重新分配。
  int totalFeeMinor;

  InstallmentContractStatus _status;
  String? note;
  final DateTime createdAt;

  InstallmentContractStatus get status => _status;

  void reviseTerms({
    int? totalPeriods,
    DateTime? firstRepaymentDate,
    DateTime? lastRepaymentDate,
    DateTime? borrowingDate,
    InstallmentRepaymentMethod? repaymentMethod,
    Patch<InterestRatePeriod>? interestRatePeriod,
    Patch<int>? interestRatePpm,
    InterestAccrualMethod? interestAccrualMethod,
    int? totalFeeMinor,
    Patch<String>? note,
    String? disbursementAccountId,
  }) {
    ensureEditable();
    if (disbursementAccountId != null &&
        sourceType != InstallmentSourceType.disbursement) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: 'Only disbursement contracts carry a disbursement account.',
      );
    }
    if (disbursementAccountId != null && disbursementTransactionId == null) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message:
            'A contract without a disbursement transaction cannot carry a disbursement account.',
      );
    }
    final effectiveTotalPeriods = totalPeriods ?? this.totalPeriods;
    final effectiveFirstRepaymentDate =
        firstRepaymentDate ?? this.firstRepaymentDate;
    final effectiveLastRepaymentDate =
        lastRepaymentDate ?? this.lastRepaymentDate;
    final effectiveInterestRatePeriod = _patchedValue(
      this.interestRatePeriod,
      interestRatePeriod,
    );
    final effectiveInterestRatePpm = _patchedValue(
      this.interestRatePpm,
      interestRatePpm,
    );
    final effectiveTotalFeeMinor = totalFeeMinor ?? this.totalFeeMinor;
    if (effectiveTotalPeriods <= 0) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: 'Total periods must be greater than zero.',
      );
    }
    if (effectiveTotalPeriods > 1 &&
        !effectiveLastRepaymentDate.isAfter(effectiveFirstRepaymentDate)) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: 'Last repayment date must be after first.',
      );
    }
    _financialTerms.validate(
      totalFeeMinor: effectiveTotalFeeMinor,
      interestRatePeriod: effectiveInterestRatePeriod,
      interestRatePpm: effectiveInterestRatePpm,
    );
    if (totalPeriods != null) this.totalPeriods = totalPeriods;
    if (firstRepaymentDate != null) {
      this.firstRepaymentDate = firstRepaymentDate;
    }
    if (lastRepaymentDate != null) this.lastRepaymentDate = lastRepaymentDate;
    if (borrowingDate != null) this.borrowingDate = borrowingDate;
    if (repaymentMethod != null) this.repaymentMethod = repaymentMethod;
    if (interestRatePeriod != null) {
      this.interestRatePeriod = switch (interestRatePeriod) {
        PatchSet<InterestRatePeriod>(:final value) => value,
        PatchClear<InterestRatePeriod>() => null,
      };
    }
    if (interestRatePpm != null) {
      this.interestRatePpm = switch (interestRatePpm) {
        PatchSet<int>(:final value) => value,
        PatchClear<int>() => null,
      };
    }
    if (interestAccrualMethod != null) {
      this.interestAccrualMethod = interestAccrualMethod;
    }
    if (totalFeeMinor != null) this.totalFeeMinor = totalFeeMinor;
    if (note != null) {
      this.note = switch (note) {
        PatchSet<String>(:final value) => value,
        PatchClear<String>() => null,
      };
    }
    if (disbursementAccountId != null) {
      this.disbursementAccountId = disbursementAccountId;
    }
  }

  T? _patchedValue<T>(T? current, Patch<T>? patch) {
    return switch (patch) {
      null => current,
      PatchSet<T>(:final value) => value,
      PatchClear<T>() => null,
    };
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
