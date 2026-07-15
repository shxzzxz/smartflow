import '../../../../core/error/app_exception.dart';
import '../../../../core/money/money.dart';
import '../../entity/installment_contract.dart';
import '../../entity/installment_schedule.dart';
import '../../valobj/credit_error_code.dart';
import '../../valobj/installment_enums.dart';
import 'installment_plan_engine.dart';

class InstallmentScheduleRecalculation {
  const InstallmentScheduleRecalculation({
    required this.scheduleId,
    required this.periodNo,
    required this.expectedRepaymentDate,
    required this.expectedPrincipal,
    required this.expectedInterest,
    required this.expectedFee,
  });

  final String scheduleId;
  final int periodNo;
  final DateTime expectedRepaymentDate;
  final Money expectedPrincipal;
  final Money expectedInterest;
  final Money expectedFee;
}

class InstallmentPrepaymentRecalculator {
  const InstallmentPrepaymentRecalculator({
    InstallmentPlanEngine planEngine = const InstallmentPlanEngine(),
  }) : _planEngine = planEngine;

  final InstallmentPlanEngine _planEngine;

  List<InstallmentScheduleRecalculation> recalculateAllPending({
    required InstallmentContract contract,
    required List<InstallmentSchedule> schedules,
    required int prepaymentPrincipalMinor,
    int? equalInstallmentOverrideMinor,
  }) {
    return _recalculateAllPending(
      contract: contract,
      schedules: schedules,
      prepaymentPrincipalMinor: prepaymentPrincipalMinor,
      equalInstallmentOverrideMinor: equalInstallmentOverrideMinor,
    );
  }

  List<InstallmentScheduleRecalculation>
  recalculateAllPendingWithRegeneratedDates({
    required InstallmentContract contract,
    required List<InstallmentSchedule> schedules,
    required int prepaymentPrincipalMinor,
    int? equalInstallmentOverrideMinor,
  }) {
    final generatedDates = _planEngine.generateDates(
      firstRepaymentDate: contract.firstRepaymentDate,
      lastRepaymentDate: contract.lastRepaymentDate,
      totalPeriods: contract.totalPeriods,
    );
    final repaymentDateByPeriodNo = {
      for (var index = 0; index < generatedDates.length; index++)
        index + 1: generatedDates[index],
    };
    return _recalculateAllPending(
      contract: contract,
      schedules: schedules,
      prepaymentPrincipalMinor: prepaymentPrincipalMinor,
      equalInstallmentOverrideMinor: equalInstallmentOverrideMinor,
      pendingRepaymentDateByPeriodNo: repaymentDateByPeriodNo,
    );
  }

  List<InstallmentScheduleRecalculation> _recalculateAllPending({
    required InstallmentContract contract,
    required List<InstallmentSchedule> schedules,
    required int prepaymentPrincipalMinor,
    int? equalInstallmentOverrideMinor,
    Map<int, DateTime>? pendingRepaymentDateByPeriodNo,
  }) {
    final fixed =
        schedules
            .where(
              (schedule) =>
                  schedule.status != InstallmentScheduleStatus.pending,
            )
            .toList()
          ..sort((a, b) => a.periodNo.compareTo(b.periodNo));
    final pending =
        schedules
            .where(
              (schedule) =>
                  schedule.status == InstallmentScheduleStatus.pending,
            )
            .toList()
          ..sort((a, b) => a.periodNo.compareTo(b.periodNo));
    return _recalculate(
      contract: contract,
      fixed: fixed,
      pending: pending,
      prepaymentPrincipalMinor: prepaymentPrincipalMinor,
      equalInstallmentOverrideMinor: equalInstallmentOverrideMinor,
      pendingRepaymentDateByPeriodNo: pendingRepaymentDateByPeriodNo,
    );
  }

  List<InstallmentScheduleRecalculation> _recalculate({
    required InstallmentContract contract,
    required List<InstallmentSchedule> fixed,
    required List<InstallmentSchedule> pending,
    required int prepaymentPrincipalMinor,
    int? equalInstallmentOverrideMinor,
    Map<int, DateTime>? pendingRepaymentDateByPeriodNo,
  }) {
    final timeline = [...fixed, ...pending]
      ..sort((a, b) => a.periodNo.compareTo(b.periodNo));
    final effectiveRepaymentDateByScheduleId = {
      for (final schedule in timeline)
        schedule.id: _effectiveRepaymentDate(
          schedule,
          pendingRepaymentDateByPeriodNo,
        ),
    };
    _validateTimeline(
      contract.borrowingDate,
      timeline,
      effectiveRepaymentDateByScheduleId,
    );
    if (pending.isEmpty) return const [];

    final fixedPrincipalMinor = fixed.fold<int>(
      0,
      (sum, schedule) => sum + schedule.expectedPrincipal.minorUnits,
    );
    final remainingMinor =
        contract.principal.minorUnits -
        fixedPrincipalMinor -
        prepaymentPrincipalMinor;
    if (remainingMinor < 0) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: 'Remaining principal would be negative.',
      );
    }

    final fixedFeeMinor = fixed.fold<int>(
      0,
      (sum, schedule) => sum + schedule.expectedFee.minorUnits,
    );
    final remainingFeeMinor = contract.totalFeeMinor - fixedFeeMinor;
    final accrualStartByScheduleId = <String, DateTime>{};
    var previousDate = contract.borrowingDate;
    for (final schedule in timeline) {
      accrualStartByScheduleId[schedule.id] = previousDate;
      previousDate = effectiveRepaymentDateByScheduleId[schedule.id]!;
    }
    final additionalOutstandingPrincipalByScheduleId = <String, int>{};
    var futureFixedPrincipalMinor = 0;
    for (final schedule in timeline.reversed) {
      if (schedule.status == InstallmentScheduleStatus.pending) {
        additionalOutstandingPrincipalByScheduleId[schedule.id] =
            futureFixedPrincipalMinor;
      } else {
        futureFixedPrincipalMinor += schedule.expectedPrincipal.minorUnits;
      }
    }
    final entries = _planEngine.plan(
      InstallmentPlanConfig.withAccrualPeriods(
        remainingPrincipal: Money(minorUnits: remainingMinor),
        firstPeriodNo: pending.first.periodNo,
        accrualPeriods: [
          for (final schedule in pending)
            InstallmentAccrualPeriod(
              accrualStartDate: accrualStartByScheduleId[schedule.id]!,
              repaymentDate: effectiveRepaymentDateByScheduleId[schedule.id]!,
              additionalOutstandingPrincipal: Money(
                minorUnits:
                    additionalOutstandingPrincipalByScheduleId[schedule.id]!,
              ),
            ),
        ],
        repaymentMethod: contract.repaymentMethod,
        interestAccrualMethod: contract.interestAccrualMethod,
        interestRatePeriod: contract.interestRatePeriod,
        interestRatePpm: contract.interestRatePpm,
        remainingFeeMinor: remainingFeeMinor < 0 ? 0 : remainingFeeMinor,
        equalInstallmentOverrideMinor: equalInstallmentOverrideMinor,
      ),
    );

    return [
      for (var i = 0; i < pending.length; i++)
        InstallmentScheduleRecalculation(
          scheduleId: pending[i].id,
          periodNo: pending[i].periodNo,
          expectedRepaymentDate:
              effectiveRepaymentDateByScheduleId[pending[i].id]!,
          expectedPrincipal: entries[i].expectedPrincipal,
          expectedInterest: entries[i].expectedInterest,
          expectedFee: entries[i].expectedFee,
        ),
    ];
  }

  void _validateTimeline(
    DateTime borrowingDate,
    List<InstallmentSchedule> timeline,
    Map<String, DateTime> effectiveRepaymentDateByScheduleId,
  ) {
    var previousDate = borrowingDate;
    for (final schedule in timeline) {
      final repaymentDate = effectiveRepaymentDateByScheduleId[schedule.id]!;
      if (!repaymentDate.isAfter(previousDate)) {
        throw BusinessException(
          CreditErrorCode.contractInvalidCommand,
          message:
              'Schedule dates must be strictly increasing by period number.',
        );
      }
      previousDate = repaymentDate;
    }
  }

  DateTime _effectiveRepaymentDate(
    InstallmentSchedule schedule,
    Map<int, DateTime>? pendingRepaymentDateByPeriodNo,
  ) {
    if (schedule.status != InstallmentScheduleStatus.pending ||
        pendingRepaymentDateByPeriodNo == null) {
      return schedule.expectedRepaymentDate;
    }
    final regeneratedDate = pendingRepaymentDateByPeriodNo[schedule.periodNo];
    if (regeneratedDate == null) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: 'Pending schedule period is outside the contract terms.',
      );
    }
    return regeneratedDate;
  }
}
