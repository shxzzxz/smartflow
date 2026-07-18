import '../../../application/credit/credit_query_api.dart';

String billRepaymentDateText(BillRepaymentReadModel repayment) {
  final prefix =
      repayment.timeSource == BillRepaymentTimeSource.transaction
          ? '还款日'
          : '记录于';
  return '$prefix ${_dateLabel(repayment.displayTime)}';
}

String billRepaymentBreakdownText(BillRepaymentReadModel repayment) {
  final amount = repayment.allocated;
  return '本 ${amount.principal.format()} '
      '息 ${amount.interest.format()} '
      '费 ${amount.fee.format()}';
}

String _dateLabel(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
