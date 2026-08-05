import '../../../core/money/money.dart';
import '../../../core/time/month_key.dart';

class Budget {
  Budget({
    required this.id,
    required this.month,
    required this.amount,
    required this.sortOrder,
    this.categoryId,
  });

  final String id;
  final MonthKey month;
  final String? categoryId;
  Money amount;
  int sortOrder;

  bool get isTotal => categoryId == null;

  void changeAmount(Money value) => amount = value;

  void reorder(int value) => sortOrder = value;
}
