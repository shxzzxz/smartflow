import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/bill_period.dart';
import 'package:smartflow/domain/credit/valobj/credit_account_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

import '../../repayment/repayment_amount_dto.dart';

class BillSummaryReadModel {
  const BillSummaryReadModel({
    required this.id,
    required this.accountId,
    required this.period,
    required this.status,
    required this.expectedPrincipal,
    required this.expectedInterest,
    required this.expectedFee,
    required this.pendingPrincipal,
    this.pendingTotal,
    required this.itemCount,
    required this.overdueItemCount,
    this.windowStartDate,
    this.windowBillingDate,
    this.windowRepaymentDate,
  });

  final String id;
  final String accountId;
  final BillPeriod period;
  final BillStatus status;

  /// Legacy nullable fields retained for API compatibility. New projections
  /// expose the consumption window and repayment date on each bill item.
  final DateTime? windowStartDate;
  final DateTime? windowBillingDate;
  final DateTime? windowRepaymentDate;
  final Money expectedPrincipal;
  final Money expectedInterest;
  final Money expectedFee;
  final Money pendingPrincipal;

  /// Remaining total for outstanding bill items, including interest and fees.
  ///
  /// Nullable for compatibility with callers that construct this read model
  /// directly; query services populate it for persisted bills.
  final Money? pendingTotal;
  final int itemCount;
  final int overdueItemCount;

  Money get totalAmount => expectedPrincipal + expectedInterest + expectedFee;

  Money get pendingAmount => pendingTotal ?? pendingPrincipal;
}

class BillDetailReadModel {
  const BillDetailReadModel({
    required this.summary,
    required this.items,
    required this.repayments,
  });

  final BillSummaryReadModel summary;
  final List<BillItemReadModel> items;
  final List<BillRepaymentReadModel> repayments;
}

class BillItemReadModel {
  const BillItemReadModel({
    required this.id,
    required this.itemType,
    required this.status,
    required this.repaymentDate,
    this.billingState = BillItemBillingState.billed,
    this.startInclusive,
    this.endInclusive,
    required this.expectedPrincipal,
    required this.expectedInterest,
    required this.expectedFee,
    required this.allocated,
    required this.isOverdue,
    this.accountKind,
    this.installmentSourceType,
    this.contractId,
    this.scheduleId,
  });

  final String id;
  final BillItemType itemType;
  final BillItemStatus status;
  final DateTime repaymentDate;
  final BillItemBillingState billingState;
  final DateTime? startInclusive;
  final DateTime? endInclusive;
  final Money expectedPrincipal;
  final Money expectedInterest;
  final Money expectedFee;
  final RepaymentAmountDto allocated;
  final bool isOverdue;
  final CreditLiabilityAccountKind? accountKind;
  final InstallmentSourceType? installmentSourceType;
  final String? contractId;
  final String? scheduleId;

  Money get remainingPrincipal =>
      _remaining(expectedPrincipal, allocated.principal);

  Money get remainingInterest =>
      _remaining(expectedInterest, allocated.interest);

  Money get remainingFee => _remaining(expectedFee, allocated.fee);

  /// Total amount still payable for this bill item.
  ///
  /// Discounts reduce the amount due even though they are not one of the
  /// expected amount components.
  Money get remainingTotal {
    if (status == BillItemStatus.paid || status == BillItemStatus.overpaid) {
      return Money.zero();
    }
    final remaining =
        remainingPrincipal.minorUnits +
        remainingInterest.minorUnits +
        remainingFee.minorUnits -
        allocated.discount.minorUnits;
    return Money(minorUnits: remaining < 0 ? 0 : remaining);
  }

  static Money _remaining(Money expected, Money allocated) {
    final remaining = expected.minorUnits - allocated.minorUnits;
    return Money(minorUnits: remaining < 0 ? 0 : remaining);
  }
}

class BillRepaymentReadModel {
  const BillRepaymentReadModel({
    required this.id,
    required this.repaymentType,
    required this.allocated,
    required this.displayTime,
    this.transactionId,
    this.paidFromAccountId,
  });

  final String id;
  final RepaymentType repaymentType;
  final RepaymentAmountDto allocated;
  final DateTime displayTime;
  final String? transactionId;
  final String? paidFromAccountId;

  Money get cashPaid =>
      allocated.principal +
      allocated.interest +
      allocated.fee -
      allocated.discount;
}
