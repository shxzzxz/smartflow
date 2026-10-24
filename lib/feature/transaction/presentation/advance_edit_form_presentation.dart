import '../../../core/money/money.dart';

String? validateAdvanceCollectionAmount({
  required String amountText,
  required Money? outstanding,
}) {
  final amount = Money.tryParse(amountText);
  if (amount == null || amount.minorUnits <= 0) {
    return '请输入有效到账金额';
  }
  if (outstanding != null && amount.minorUnits > outstanding.minorUnits) {
    return '到账金额不能超过剩余应收';
  }
  return null;
}

String? advanceSettlementGapMessage({
  required String amountText,
  required Money? outstandingBeforeTransaction,
}) {
  final actual = Money.tryParse(amountText);
  if (actual == null || outstandingBeforeTransaction == null) return null;

  final gap = actual - outstandingBeforeTransaction;
  if (gap.minorUnits == 0) return null;
  return gap.minorUnits > 0
      ? '多收 ${gap.format()}（计入垫付补偿）'
      : '少收 ${gap.abs().format()}（计入自承担支出分类）';
}

String? validateAdvanceReceiveAccount({
  required bool isClose,
  required String amountText,
  required String? accountId,
}) {
  if (isClose) {
    final actual = Money.tryParse(amountText);
    if (actual == null || actual.minorUnits == 0) return null;
  }
  return accountId == null ? '请选择账户' : null;
}
