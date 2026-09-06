import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/entity/credit_liability_account.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/service/installment/installment_lifecycle_service.dart';
import 'package:smartflow/domain/credit/service/installment/installment_financial_terms_policy.dart';
import 'package:smartflow/domain/credit/service/installment/installment_plan_engine.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_dates_strategy.dart';

class InstallmentOriginationTerms {
  const InstallmentOriginationTerms({
    required this.principal,
    required this.totalPeriods,
    required this.borrowingDate,
    required this.firstRepaymentDate,
    required this.repaymentMethod,
    required this.interestAccrualMethod,
    required this.totalFeeMinor,
    this.lastRepaymentDate,
    this.interestRatePeriod,
    this.interestRatePpm,
    this.equalInstallmentOverrideMinor,
    this.note,
  });

  final Money principal;
  final int totalPeriods;
  final DateTime borrowingDate;
  final DateTime firstRepaymentDate;
  final DateTime? lastRepaymentDate;
  final InstallmentRepaymentMethod repaymentMethod;
  final InterestRatePeriod? interestRatePeriod;
  final int? interestRatePpm;
  final InterestAccrualMethod interestAccrualMethod;
  final int totalFeeMinor;
  final int? equalInstallmentOverrideMinor;
  final String? note;
}

class InstallmentOriginationResult {
  const InstallmentOriginationResult({
    required this.contract,
    required this.schedules,
  });

  final InstallmentContract contract;
  final List<InstallmentSchedule> schedules;
}

class InstallmentOriginationService {
  static const _financialTerms = InstallmentFinancialTermsPolicy();

  const InstallmentOriginationService({
    InstallmentPlanEngine planEngine = const InstallmentPlanEngine(),
    InstallmentLifecycleService lifecycle = const InstallmentLifecycleService(),
  }) : _planEngine = planEngine,
       _lifecycle = lifecycle;

  final InstallmentPlanEngine _planEngine;
  final InstallmentLifecycleService _lifecycle;

  InstallmentOriginationResult originateDisbursement({
    required String contractId,
    required String liabilityAccountId,
    required InstallmentOriginationTerms terms,
    required DateTime createdAt,
    required String Function() newScheduleId,
    CreditLiabilityAccount? creditAccount,
    String? disbursementAccountId,
    String? disbursementTransactionId,
  }) {
    final cycleBounds = _lifecycle.cycleScheduleBoundsForDisbursement(
      creditAccount,
      borrowingDate: terms.borrowingDate,
      totalPeriods: terms.totalPeriods,
    );
    return _originate(
      contractId: contractId,
      liabilityAccountId: liabilityAccountId,
      sourceType: InstallmentSourceType.disbursement,
      disbursementAccountId: disbursementAccountId,
      disbursementTransactionId: disbursementTransactionId,
      terms: InstallmentOriginationTerms(
        principal: terms.principal,
        totalPeriods: terms.totalPeriods,
        borrowingDate: terms.borrowingDate,
        firstRepaymentDate: cycleBounds?.first ?? terms.firstRepaymentDate,
        lastRepaymentDate: cycleBounds?.last ?? terms.lastRepaymentDate,
        repaymentMethod: terms.repaymentMethod,
        interestRatePeriod: terms.interestRatePeriod,
        interestRatePpm: terms.interestRatePpm,
        interestAccrualMethod: terms.interestAccrualMethod,
        totalFeeMinor: terms.totalFeeMinor,
        equalInstallmentOverrideMinor: terms.equalInstallmentOverrideMinor,
        note: terms.note,
      ),
      createdAt: createdAt,
      newScheduleId: newScheduleId,
    );
  }

  InstallmentOriginationResult originateBillConversion({
    required String contractId,
    required Bill bill,
    required String sourceRepaymentId,
    required Money principal,
    required int totalPeriods,
    required InstallmentRepaymentMethod repaymentMethod,
    required InterestAccrualMethod interestAccrualMethod,
    required int totalFeeMinor,
    required DateTime createdAt,
    required String Function() newScheduleId,
    DateTime? borrowingDate,
    DateTime? firstRepaymentDate,
    DateTime? lastRepaymentDate,
    InterestRatePeriod? interestRatePeriod,
    int? interestRatePpm,
    int? equalInstallmentOverrideMinor,
    String? note,
  }) {
    final effectiveBorrowingDate = borrowingDate ?? _defaultBorrowingDate(bill);
    final effectiveFirstDate =
        firstRepaymentDate ?? _addMonths(effectiveBorrowingDate, 1);
    return _originate(
      contractId: contractId,
      liabilityAccountId: bill.accountId,
      sourceType: InstallmentSourceType.billConversion,
      sourceRepaymentId: sourceRepaymentId,
      terms: InstallmentOriginationTerms(
        principal: principal,
        totalPeriods: totalPeriods,
        borrowingDate: effectiveBorrowingDate,
        firstRepaymentDate: effectiveFirstDate,
        lastRepaymentDate: lastRepaymentDate,
        repaymentMethod: repaymentMethod,
        interestRatePeriod: interestRatePeriod,
        interestRatePpm: interestRatePpm,
        interestAccrualMethod: interestAccrualMethod,
        totalFeeMinor: totalFeeMinor,
        equalInstallmentOverrideMinor: equalInstallmentOverrideMinor,
        note: note,
      ),
      createdAt: createdAt,
      newScheduleId: newScheduleId,
    );
  }

  InstallmentOriginationResult _originate({
    required String contractId,
    required String liabilityAccountId,
    required InstallmentSourceType sourceType,
    required InstallmentOriginationTerms terms,
    required DateTime createdAt,
    required String Function() newScheduleId,
    String? sourceRepaymentId,
    String? disbursementAccountId,
    String? disbursementTransactionId,
  }) {
    final lastDate =
        terms.lastRepaymentDate ??
        _lifecycle.defaultLastDate(
          terms.firstRepaymentDate,
          terms.totalPeriods,
        );
    _validateTerms(terms, lastDate);
    final entries = _planEngine.generate(
      principal: terms.principal,
      borrowingDate: terms.borrowingDate,
      firstRepaymentDate: terms.firstRepaymentDate,
      lastRepaymentDate: lastDate,
      totalPeriods: terms.totalPeriods,
      method: terms.repaymentMethod,
      accrualMethod: terms.interestAccrualMethod,
      ratePeriod: terms.interestRatePeriod,
      ratePpm: terms.interestRatePpm,
      totalFeeMinor: terms.totalFeeMinor,
      equalInstallmentOverrideMinor: terms.equalInstallmentOverrideMinor,
    );
    final contract = InstallmentContract(
      id: contractId,
      liabilityAccountId: liabilityAccountId,
      sourceType: sourceType,
      sourceRepaymentId: sourceRepaymentId,
      disbursementAccountId: disbursementAccountId,
      disbursementTransactionId: disbursementTransactionId,
      principal: terms.principal,
      totalPeriods: terms.totalPeriods,
      borrowingDate: terms.borrowingDate,
      firstRepaymentDate: terms.firstRepaymentDate,
      lastRepaymentDate: lastDate,
      repaymentMethod: terms.repaymentMethod,
      interestRatePeriod: terms.interestRatePeriod,
      interestRatePpm: terms.interestRatePpm,
      interestAccrualMethod: terms.interestAccrualMethod,
      totalFeeMinor: terms.totalFeeMinor,
      status: InstallmentContractStatus.active,
      note: terms.note,
      createdAt: createdAt,
    );
    return InstallmentOriginationResult(
      contract: contract,
      schedules: _lifecycle.schedulesFromEntries(
        contractId: contractId,
        entries: entries,
        createdAt: createdAt,
        newId: newScheduleId,
      ),
    );
  }

  void _validateTerms(InstallmentOriginationTerms terms, DateTime lastDate) {
    _lifecycle.validateCreate(
      principal: terms.principal,
      totalPeriods: terms.totalPeriods,
      firstRepaymentDate: terms.firstRepaymentDate,
      lastRepaymentDate: lastDate,
    );
    _financialTerms.validate(
      totalFeeMinor: terms.totalFeeMinor,
      interestRatePeriod: terms.interestRatePeriod,
      interestRatePpm: terms.interestRatePpm,
    );
    if ((terms.equalInstallmentOverrideMinor ?? 0) < 0) {
      throw BusinessException(CreditErrorCode.contractInvalidCommand);
    }
  }

  DateTime _defaultBorrowingDate(Bill bill) {
    final windowRepaymentDate = bill.window?.repaymentDate;
    if (windowRepaymentDate != null) return windowRepaymentDate;
    if (bill.items.isEmpty) {
      throw BusinessException(CreditErrorCode.contractInvalidCommand);
    }
    return bill.items
        .map((item) => item.repaymentDate)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  DateTime _addMonths(DateTime date, int months) {
    return IntervalRepaymentDates(
      firstDate: date,
      count: months + 1,
    ).getDates().last;
  }
}
