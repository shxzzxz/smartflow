import '../../../core/money/money.dart';
import '../../../core/time/month_key.dart';

class Budget {
  const Budget({
    required this.id,
    required this.monthKey,
    required this.amount,
    this.accountId,
  });

  final String id;
  final MonthKey monthKey;
  final String? accountId;
  final Money amount;
}
