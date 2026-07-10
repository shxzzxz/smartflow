import '../../../core/money/money.dart';
import '../../../core/error/app_exception.dart';
import '../valobj/credit_error_code.dart';
import '../valobj/installment_enums.dart';
import 'installment_schedule.dart';

class InstallmentContract {
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
    InterestRatePeriod? interestRatePeriod,
    int? interestRatePpm,
    InterestAccrualMethod? interestAccrualMethod,
    int? totalFeeMinor,
    String? note,
    String? disbursementAccountId,
  }) {
    if (totalPeriods != null) this.totalPeriods = totalPeriods;
    if (firstRepaymentDate != null) {
      this.firstRepaymentDate = firstRepaymentDate;
    }
    if (lastRepaymentDate != null) this.lastRepaymentDate = lastRepaymentDate;
    if (borrowingDate != null) this.borrowingDate = borrowingDate;
    if (repaymentMethod != null) this.repaymentMethod = repaymentMethod;
    if (interestRatePeriod != null) {
      this.interestRatePeriod = interestRatePeriod;
    }
    if (interestRatePpm != null) this.interestRatePpm = interestRatePpm;
    if (interestAccrualMethod != null) {
      this.interestAccrualMethod = interestAccrualMethod;
    }
    if (totalFeeMinor != null) this.totalFeeMinor = totalFeeMinor;
    if (note != null) this.note = note;
    if (disbursementAccountId != null) {
      this.disbursementAccountId = disbursementAccountId;
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

  void refreshStatusFromSchedules(List<InstallmentSchedule> schedules) {
    if (schedules.isEmpty) return;
    for (final schedule in schedules) {
      _ensureScheduleBelongsToContract(schedule);
    }
    final hasOutstanding = schedules.any(
      (schedule) =>
          schedule.status == InstallmentScheduleStatus.pending ||
          schedule.status == InstallmentScheduleStatus.partiallyPaid,
    );
    if (hasOutstanding) {
      _status = InstallmentContractStatus.active;
      return;
    }
    final allDone = schedules.every(
      (schedule) =>
          schedule.status == InstallmentScheduleStatus.paid ||
          schedule.status == InstallmentScheduleStatus.skipped,
    );
    if (allDone) {
      _status = InstallmentContractStatus.settled;
    }
  }

  void _ensureScheduleBelongsToContract(InstallmentSchedule schedule) {
    if (schedule.contractId != id) {
      throw BusinessException(
        CreditErrorCode.scheduleNotFound,
        message: 'Schedule does not belong to the contract.',
      );
    }
  }
}
