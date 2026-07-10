import '../../../../core/error/app_exception.dart';
import '../../../../core/money/money.dart';
import '../../entity/installment_contract.dart';
import '../../entity/installment_schedule.dart';
import '../../valobj/credit_error_code.dart';
import '../../valobj/installment_enums.dart';
import 'installment_plan_engine.dart';
import 'repayment_dates_strategy.dart';

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
    final fixed =
        schedules
            .where(
              (schedule) => schedule.status == InstallmentScheduleStatus.paid,
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
    );
  }

  List<InstallmentScheduleRecalculation> recalculateAfterPrepayment({
    required InstallmentContract contract,
    required List<InstallmentSchedule> schedules,
    required DateTime occurredAt,
    required int prepaymentPrincipalMinor,
  }) {
    final fixed =
        schedules
            .where(
              (schedule) => schedule.status == InstallmentScheduleStatus.paid,
            )
            .followedBy(
              schedules.where(
                (schedule) =>
                    schedule.status == InstallmentScheduleStatus.pending &&
                    !schedule.expectedRepaymentDate.isAfter(occurredAt),
              ),
            )
            .toList()
          ..sort((a, b) => a.periodNo.compareTo(b.periodNo));
    final pending =
        schedules
            .where(
              (schedule) =>
                  schedule.status == InstallmentScheduleStatus.pending &&
                  schedule.expectedRepaymentDate.isAfter(occurredAt),
            )
            .toList()
          ..sort((a, b) => a.periodNo.compareTo(b.periodNo));
    return _recalculate(
      contract: contract,
      fixed: fixed,
      pending: pending,
      prepaymentPrincipalMinor: prepaymentPrincipalMinor,
    );
  }

  List<InstallmentScheduleRecalculation> recalculatePendingAfter({
    required InstallmentContract contract,
    required List<InstallmentSchedule> schedules,
    required DateTime occurredAt,
    required int prepaymentPrincipalMinor,
  }) {
    return recalculateAfterPrepayment(
      contract: contract,
      schedules: schedules,
      occurredAt: occurredAt,
      prepaymentPrincipalMinor: prepaymentPrincipalMinor,
    );
  }

  List<InstallmentScheduleRecalculation> _recalculate({
    required InstallmentContract contract,
    required List<InstallmentSchedule> fixed,
    required List<InstallmentSchedule> pending,
    required int prepaymentPrincipalMinor,
    int? equalInstallmentOverrideMinor,
  }) {
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
    final anchorDate =
        fixed.isEmpty
            ? contract.borrowingDate
            : fixed.last.expectedRepaymentDate;
    final entries = _planEngine.plan(
      InstallmentPlanConfig(
        remainingPrincipal: Money(minorUnits: remainingMinor),
        firstPeriodNo: pending.first.periodNo,
        accrualStartDate: anchorDate,
        repaymentDates: ExplicitRepaymentDates([
          for (final schedule in pending) schedule.expectedRepaymentDate,
        ]),
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
          expectedRepaymentDate: pending[i].expectedRepaymentDate,
          expectedPrincipal: entries[i].expectedPrincipal,
          expectedInterest: entries[i].expectedInterest,
          expectedFee: entries[i].expectedFee,
        ),
    ];
  }
}
