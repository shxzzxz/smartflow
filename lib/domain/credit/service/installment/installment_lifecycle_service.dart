import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/credit_liability_account.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/domain/credit/service/installment/installment_plan_engine.dart';
import 'package:smartflow/domain/credit/valobj/bill_period.dart';
import 'package:smartflow/domain/credit/valobj/credit_account_enums.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_dates_strategy.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

class InstallmentLifecycleService {
  const InstallmentLifecycleService();

  void validateCreate({
    required Money principal,
    required int totalPeriods,
    required DateTime firstRepaymentDate,
    DateTime? lastRepaymentDate,
  }) {
    if (principal.minorUnits <= 0) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: 'Installment principal must be positive.',
      );
    }
    if (totalPeriods <= 0) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: 'Total periods must be greater than zero.',
      );
    }
    if (lastRepaymentDate != null &&
        totalPeriods > 1 &&
        !lastRepaymentDate.isAfter(firstRepaymentDate)) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: 'Last repayment date must be after first.',
      );
    }
  }

  DateTime defaultLastDate(DateTime firstDate, int totalPeriods) {
    return IntervalRepaymentDates(
      firstDate: firstDate,
      count: totalPeriods,
    ).getDates().last;
  }

  ({DateTime first, DateTime last})? cycleScheduleBoundsForDisbursement(
    CreditLiabilityAccount? account, {
    required DateTime borrowingDate,
    required int totalPeriods,
  }) {
    if (account == null || account.kind != CreditLiabilityAccountKind.credit) {
      return null;
    }

    final currentPeriod = account.creditPeriodForDate(borrowingDate);
    final firstPeriod = currentPeriod.next();
    final lastPeriod = _advancePeriod(firstPeriod, totalPeriods - 1);
    return (
      first: account.nextCreditBillWindow(firstPeriod).repaymentDate,
      last: account.nextCreditBillWindow(lastPeriod).repaymentDate,
    );
  }

  List<InstallmentSchedule> schedulesFromEntries({
    required String contractId,
    required List<InstallmentSchedulePlanEntry> entries,
    required DateTime createdAt,
    required String Function() newId,
    Map<int, String> stageIdsByPeriod = const {},
  }) {
    return [
      for (final entry in entries)
        InstallmentSchedule(
          id: newId(),
          contractId: contractId,
          stageId: stageIdsByPeriod[entry.periodNo],
          periodNo: entry.periodNo,
          expectedRepaymentDate: entry.expectedRepaymentDate,
          expectedPrincipal: entry.expectedPrincipal,
          expectedInterest: entry.expectedInterest,
          expectedFee: entry.expectedFee,
          status: InstallmentScheduleStatus.pending,
          createdAt: createdAt,
        ),
    ];
  }

  int prepaymentPrincipalMinor(List<Repayment> repayments) {
    return repayments
        .where(
          (repayment) => repayment.repaymentType == RepaymentType.prepayment,
        )
        .fold<int>(
          0,
          (sum, repayment) =>
              sum + repayment.totalAllocated().principal.minorUnits,
        );
  }

  InstallmentContractStatus projectContractStatus({
    required InstallmentContract contract,
    required List<InstallmentSchedule> schedules,
  }) {
    final current = contract.status;
    contract.refreshStatusFromSchedules(schedules);
    return contract.status == current ? current : contract.status;
  }

  void validateDelete({
    required List<Repayment> repayments,
    required List<InstallmentSchedule> schedules,
  }) {
    if (repayments.isNotEmpty) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: 'Contracts with prepayments cannot be deleted directly.',
      );
    }
    final hasSettledSchedule = schedules.any(
      (schedule) =>
          schedule.status == InstallmentScheduleStatus.partiallyPaid ||
          schedule.status == InstallmentScheduleStatus.paid,
    );
    if (hasSettledSchedule) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: 'Contracts with paid schedules cannot be deleted directly.',
      );
    }
  }

  BillPeriod _advancePeriod(BillPeriod period, int months) {
    var result = period;
    for (var i = 0; i < months; i++) {
      result = result.next();
    }
    return result;
  }
}
