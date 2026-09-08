import 'bill_period.dart';

/// The user-facing, closed consumption interval for a credit bill.
class ConsumptionWindow {
  const ConsumptionWindow({
    required this.startInclusive,
    required this.endInclusive,
  });

  final DateTime startInclusive;
  final DateTime endInclusive;

  @override
  bool operator ==(Object other) {
    return other is ConsumptionWindow &&
        other.startInclusive == startInclusive &&
        other.endInclusive == endInclusive;
  }

  @override
  int get hashCode => Object.hash(startInclusive, endInclusive);
}

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
