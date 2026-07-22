import '../../../core/money/money.dart';

String? reimbursementCloseGapMessage({
  required String amountText,
  required Money? outstandingBeforeTransaction,
}) {
  final actual = Money.tryParse(amountText);
  if (actual == null || outstandingBeforeTransaction == null) return null;

  final gap = actual - outstandingBeforeTransaction;
  if (gap.minorUnits == 0) return null;
  return gap.minorUnits > 0
      ? '多收 ${gap.format()}（计入报销差额收入）'
      : '少收 ${gap.abs().format()}（计入原报销支出分类）';
}

String? validateReimbursementReceiveAccount({
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
