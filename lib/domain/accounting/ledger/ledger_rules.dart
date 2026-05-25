import '../enums/accounting_enums.dart';
import 'post_receipt.dart';

/// 账户余额按借贷的净增量。
///
/// - 资产 / 费用账户:借方为正
/// - 负债 / 收入 / 权益账户:贷方为正
int balanceDeltaMinor({
  required AccountType accountType,
  required EntryDirection direction,
  required int amountMinor,
}) {
  final increasesOnDebit =
      accountType == AccountType.asset || accountType == AccountType.expense;

  if (increasesOnDebit) {
    return direction == EntryDirection.debit ? amountMinor : -amountMinor;
  }

  return direction == EntryDirection.credit ? amountMinor : -amountMinor;
}

/// 给定账户类型与"目标余额变化方向(±)",返回应使用的 entry 方向。
/// OpeningBalance / BalanceAdjustment 用此公式。
EntryDirection directionForBalanceDelta({
  required AccountType accountType,
  required int deltaMinor,
}) {
  final increasesOnDebit =
      accountType == AccountType.asset || accountType == AccountType.expense;
  final increase = deltaMinor > 0;
  if (increasesOnDebit) {
    return increase ? EntryDirection.debit : EntryDirection.credit;
  }
  return increase ? EntryDirection.credit : EntryDirection.debit;
}

bool entriesAreBalanced(Iterable<ReceiptEntry> entries) {
  var debitMinor = 0;
  var creditMinor = 0;

  for (final entry in entries) {
    switch (entry.direction) {
      case EntryDirection.debit:
        debitMinor += entry.amount.minorUnits;
      case EntryDirection.credit:
        creditMinor += entry.amount.minorUnits;
    }
  }

  return debitMinor == creditMinor;
}

const _allowedPurposeByDetail = <TransactionDetailType, Set<BusinessPurpose>>{
  TransactionDetailType.primaryExpense: {BusinessPurpose.dailyExpense},
  TransactionDetailType.primaryIncome: {BusinessPurpose.dailyIncome},
  TransactionDetailType.transferMain: {BusinessPurpose.transfer},
  TransactionDetailType.transferFee: {BusinessPurpose.transfer},
  TransactionDetailType.refundMain: {BusinessPurpose.refund},
  TransactionDetailType.reimbursementAdvanceMain: {
    BusinessPurpose.reimbursementAdvance,
  },
  TransactionDetailType.reimbursementReceiptMain: {
    BusinessPurpose.reimbursementReceipt,
  },
  TransactionDetailType.reimbursementCloseMain: {
    BusinessPurpose.reimbursementClose,
  },
  TransactionDetailType.reimbursementGapExpense: {
    BusinessPurpose.reimbursementClose,
  },
  TransactionDetailType.reimbursementGapIncome: {
    BusinessPurpose.reimbursementClose,
  },
  TransactionDetailType.repaymentPrincipal: {BusinessPurpose.debtRepayment},
  TransactionDetailType.repaymentInterest: {BusinessPurpose.debtRepayment},
  TransactionDetailType.repaymentFee: {BusinessPurpose.debtRepayment},
  TransactionDetailType.repaymentDiscount: {BusinessPurpose.debtRepayment},
  TransactionDetailType.borrowingPrincipal: {BusinessPurpose.borrowing},
  TransactionDetailType.openingBalanceMain: {BusinessPurpose.openingBalance},
  TransactionDetailType.balanceAdjustmentMain: {
    BusinessPurpose.balanceAdjustment,
  },
};

bool detailTypeAllowedForPurpose({
  required TransactionDetailType detailType,
  required BusinessPurpose businessPurpose,
}) {
  return _allowedPurposeByDetail[detailType]?.contains(businessPurpose) ??
      false;
}
