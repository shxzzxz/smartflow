import '../../entity/entry.dart';
import '../../entity/transaction_detail_record.dart';
import '../../valobj/ledger_enum.dart';

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

bool entriesAreBalanced(Iterable<Object> entries) {
  var debitMinor = 0;
  var creditMinor = 0;

  for (final item in entries) {
    final (:direction, :amountMinor) = switch (item) {
      Entry(:final direction, :final amount) => (
        direction: direction,
        amountMinor: amount.minorUnits,
      ),
      _ => throw ArgumentError.value(item, 'entries', 'Unsupported entry type'),
    };
    switch (direction) {
      case EntryDirection.debit:
        debitMinor += amountMinor;
      case EntryDirection.credit:
        creditMinor += amountMinor;
    }
  }

  return debitMinor == creditMinor;
}

bool sameDetails(Iterable<Object> left, Iterable<Object> right) {
  final leftShape =
      left.map(_detailShape).toList()..sort((a, b) => a.compareTo(b));
  final rightShape =
      right.map(_detailShape).toList()..sort((a, b) => a.compareTo(b));
  if (leftShape.length != rightShape.length) return false;
  for (var i = 0; i < leftShape.length; i++) {
    if (leftShape[i] != rightShape[i]) return false;
  }
  return true;
}

bool sameEntries(Iterable<Object> left, Iterable<Object> right) {
  final leftShape =
      left.map(_entryShape).toList()..sort((a, b) => a.compareTo(b));
  final rightShape =
      right.map(_entryShape).toList()..sort((a, b) => a.compareTo(b));
  if (leftShape.length != rightShape.length) return false;
  for (var i = 0; i < leftShape.length; i++) {
    if (leftShape[i] != rightShape[i]) return false;
  }
  return true;
}

bool hasSamePostingShape(dynamic left, dynamic right) {
  return left.businessPurpose == right.businessPurpose &&
      left.primaryAmount == right.primaryAmount &&
      sameDetails(left.details, right.details) &&
      sameEntries(left.entries, right.entries);
}

String _detailShape(Object item) {
  final (:lineNo, :type, :amountMinor) = switch (item) {
    TransactionDetailRecord(:final lineNo, :final type, :final amount) => (
      lineNo: lineNo,
      type: type,
      amountMinor: amount.minorUnits,
    ),
    _ => throw ArgumentError.value(item, 'details', 'Unsupported detail type'),
  };
  return '$lineNo|${type.name}|$amountMinor';
}

String _entryShape(Object item) {
  final (:accountId, :direction, :amountMinor) = switch (item) {
    Entry(:final accountId, :final direction, :final amount) => (
      accountId: accountId,
      direction: direction,
      amountMinor: amount.minorUnits,
    ),
    _ => throw ArgumentError.value(item, 'entries', 'Unsupported entry type'),
  };
  return '$accountId|${direction.name}|$amountMinor';
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
