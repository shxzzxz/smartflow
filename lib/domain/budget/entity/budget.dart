import '../../../core/money/money.dart';
import '../../../core/time/month_key.dart';

class Budget {
  const Budget({
    required this.id,
    required this.monthKey,
    required this.amount,
    this.accountId,
  });

  final int id;
  final MonthKey monthKey;
  final int? accountId;
  final Money amount;
}
