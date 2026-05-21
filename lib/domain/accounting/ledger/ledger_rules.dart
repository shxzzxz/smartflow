import '../../../core/money/money.dart';
import '../enums/accounting_enums.dart';
import 'posting_protocol.dart';

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

bool entriesAreBalanced(Iterable<PostEntryInput> entries) {
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

bool moneyMatchesCurrency(Money money, String currencyCode) {
  return money.currency == currencyCode;
}
