import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../valobj/bill_period.dart';
import '../valobj/bill_window.dart';
import '../valobj/credit_account_enums.dart';
import '../valobj/credit_error_code.dart';

class CreditLiabilityAccountPatch {
  const CreditLiabilityAccountPatch({
    this.creditLimit,
    this.billingDay,
    this.repaymentDay,
    this.billingDayToNext,
  });

  final Patch<Money>? creditLimit;
  final Patch<int>? billingDay;
  final Patch<int>? repaymentDay;
  final bool? billingDayToNext;
}

class CreditLiabilityAccount {
  CreditLiabilityAccount({
    required this.id,
    required this.accountId,
    required this.kind,
    required this.billingDayToNext,
    this.creditLimit,
    this.billingDay,
    this.repaymentDay,
  }) {
    _ensureValid();
  }

  final String id;
  final String accountId;
  final CreditLiabilityAccountKind kind;
  Money? creditLimit;
  int? billingDay;
  int? repaymentDay;
  bool billingDayToNext;

  void updateParameters(CreditLiabilityAccountPatch patch) {
    creditLimit = patch.creditLimit.applyTo(creditLimit);
    billingDay = patch.billingDay.applyTo(billingDay);
    repaymentDay = patch.repaymentDay.applyTo(repaymentDay);
    billingDayToNext = patch.billingDayToNext ?? billingDayToNext;
    _ensureValid();
  }

  BillPeriod creditPeriodForDate(DateTime date) {
    _ensureCreditCycleConfigured();
    final day = date.day;
    if (day < billingDay! || (!billingDayToNext && day == billingDay)) {
      return BillPeriod(year: date.year, month: date.month);
    }
    final next = DateTime(date.year, date.month + 1);
    return BillPeriod(year: next.year, month: next.month);
  }

  BillWindow nextCreditBillWindow(
    BillPeriod period, {
    BillWindow? previousWindow,
  }) {
    _ensureCreditCycleConfigured();
    final previousPeriod = period.previous();
    final billingDate = DateTime(period.year, period.month, billingDay!);
    final startDate =
        previousWindow?.billingDate ??
        DateTime(previousPeriod.year, previousPeriod.month, billingDay!);
    final repaymentPeriod =
        repaymentDay! > billingDay! ? period : period.next();
    final repaymentDate = DateTime(
      repaymentPeriod.year,
      repaymentPeriod.month,
      repaymentDay!,
    );
    return BillWindow(
      period: period,
      startDate: startDate,
      billingDate: billingDate,
      repaymentDate: repaymentDate,
    );
  }

  DateTime effectiveCreditWindowStart(BillWindow window) {
    return billingDayToNext
        ? window.startDate
        : window.startDate.add(const Duration(days: 1));
  }

  DateTime effectiveCreditWindowEnd(BillWindow window) {
    return billingDayToNext
        ? window.billingDate
        : window.billingDate.add(const Duration(days: 1));
  }

  void _ensureCreditCycleConfigured() {
    if (kind != CreditLiabilityAccountKind.credit ||
        billingDay == null ||
        repaymentDay == null) {
      throw BusinessException(CreditErrorCode.accountInvalidCommand);
    }
  }

  void _ensureValid() {
    if (creditLimit != null && creditLimit!.minorUnits < 0) {
      throw BusinessException(
        CreditErrorCode.accountInvalidCommand,
        message: 'Credit limit cannot be negative.',
      );
    }

    switch (kind) {
      case CreditLiabilityAccountKind.credit:
        _ensureDay(billingDay, 'Billing day');
        _ensureDay(repaymentDay, 'Repayment day');
      case CreditLiabilityAccountKind.loan:
        if (billingDay != null || repaymentDay != null) {
          throw BusinessException(
            CreditErrorCode.accountInvalidCommand,
            message: 'Loan account must not have billing cycle parameters.',
          );
        }
    }
  }

  static void _ensureDay(int? day, String label) {
    if (day == null || day < 1 || day > 28) {
      throw BusinessException(
        CreditErrorCode.accountInvalidCommand,
        message: '$label must be between 1 and 28.',
      );
    }
  }
}
