import 'bill_period.dart';

class BillWindow {
  const BillWindow({
    required this.period,
    required this.startDate,
    required this.billingDate,
    required this.repaymentDate,
  });

  final BillPeriod period;
  final DateTime startDate;
  final DateTime billingDate;
  final DateTime repaymentDate;

  @override
  bool operator ==(Object other) {
    return other is BillWindow &&
        other.period == period &&
        other.startDate == startDate &&
        other.billingDate == billingDate &&
        other.repaymentDate == repaymentDate;
  }

  @override
  int get hashCode =>
      Object.hash(period, startDate, billingDate, repaymentDate);
}
