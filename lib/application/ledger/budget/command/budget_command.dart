import '../../../../core/money/money.dart';
import '../../../../core/time/month_key.dart';

class SetBudgetCommand {
  const SetBudgetCommand({
    required this.month,
    required this.amount,
    this.categoryId,
  });

  final MonthKey month;
  final String? categoryId;
  final Money amount;
}

class DeleteBudgetCommand {
  const DeleteBudgetCommand(this.id);

  final String id;
}

class ReorderCategoryBudgetsCommand {
  ReorderCategoryBudgetsCommand({
    required this.month,
    required List<String> orderedBudgetIds,
  }) : orderedBudgetIds = List.unmodifiable(orderedBudgetIds);

  final MonthKey month;
  final List<String> orderedBudgetIds;
}
