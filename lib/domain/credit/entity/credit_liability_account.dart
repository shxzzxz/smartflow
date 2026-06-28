import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../valobj/bill_period.dart';
import '../valobj/credit_account_enums.dart';
import '../valobj/credit_error_code.dart';

class CreditLiabilityAccountPatch {
  const CreditLiabilityAccountPatch({
    this.creditLimit,
    this.billingDay,
    this.repaymentDay,
    this.billingStartPeriod,
    this.billingDayToNext,
  });

  final Patch<Money>? creditLimit;
  final Patch<int>? billingDay;
  final Patch<int>? repaymentDay;
  final Patch<BillPeriod>? billingStartPeriod;
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
    this.billingStartPeriod,
  }) {
    _ensureValid();
  }

  final String id;
  final String accountId;
  final CreditLiabilityAccountKind kind;
  Money? creditLimit;
  int? billingDay;
  int? repaymentDay;
  BillPeriod? billingStartPeriod;
  bool billingDayToNext;

  void updateParameters(CreditLiabilityAccountPatch patch) {
    creditLimit = patch.creditLimit.applyTo(creditLimit);
    billingDay = patch.billingDay.applyTo(billingDay);
    repaymentDay = patch.repaymentDay.applyTo(repaymentDay);
    billingStartPeriod = patch.billingStartPeriod.applyTo(billingStartPeriod);
    billingDayToNext = patch.billingDayToNext ?? billingDayToNext;
    _ensureValid();
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
        if (billingStartPeriod == null) {
          throw BusinessException(
            CreditErrorCode.accountInvalidCommand,
            message: 'Billing start period is required.',
          );
        }
      case CreditLiabilityAccountKind.loan:
        if (billingDay != null ||
            repaymentDay != null ||
            billingStartPeriod != null) {
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
