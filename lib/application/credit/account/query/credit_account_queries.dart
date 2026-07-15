import 'package:smartflow/core/time/month_key.dart';

class CreditDueCalendarQuery {
  const CreditDueCalendarQuery({
    required this.from,
    required this.until,
    this.accountId,
  });

  final DateTime from;
  final DateTime until;
  final String? accountId;
}

class MonthlyBillSummaryQuery {
  const MonthlyBillSummaryQuery({required this.month, this.accountId});

  final MonthKey month;
  final String? accountId;
}
