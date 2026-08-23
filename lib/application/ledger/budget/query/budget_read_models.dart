import '../../../../core/money/money.dart';
import '../../../../core/time/month_key.dart';

class BudgetTrendPoint {
  const BudgetTrendPoint({
    required this.date,
    required this.spent,
    required this.remaining,
  });

  final DateTime date;
  final Money spent;
  final Money remaining;
}

class BudgetProgress {
  BudgetProgress({
    required this.id,
    required this.name,
    required this.budget,
    required this.spent,
    required this.sortOrder,
    required List<BudgetTrendPoint> trend,
    this.categoryId,
    this.iconKey,
  }) : trend = List.unmodifiable(trend);

  final String id;
  final String? categoryId;
  final String name;
  final String? iconKey;
  final Money budget;
  final Money spent;
  final int sortOrder;
  final List<BudgetTrendPoint> trend;

  Money get remaining => budget - spent;

  double get usedRatio {
    if (budget.minorUnits <= 0) return spent.minorUnits > 0 ? 1 : 0;
    return spent.minorUnits / budget.minorUnits;
  }

  bool get isOverspent => remaining.minorUnits < 0;
}

class BudgetCategoryGroup {
  BudgetCategoryGroup({
    required this.id,
    required this.name,
    required this.sortOrder,
    required List<BudgetProgress> childBudgets,
    this.iconKey,
    this.rootBudget,
  }) : childBudgets = List.unmodifiable(childBudgets);

  final String id;
  final String name;
  final String? iconKey;
  final int sortOrder;
  final BudgetProgress? rootBudget;
  final List<BudgetProgress> childBudgets;

  List<BudgetProgress> get budgets => [?rootBudget, ...childBudgets];
}

class MonthlyBudgetReport {
  MonthlyBudgetReport({
    required this.month,
    required List<BudgetCategoryGroup> categoryGroups,
    this.totalBudget,
  }) : categoryGroups = List.unmodifiable(categoryGroups);

  final MonthKey month;
  final BudgetProgress? totalBudget;
  final List<BudgetCategoryGroup> categoryGroups;

  List<String> get orderedCategoryBudgetIds => [
    for (final group in categoryGroups)
      for (final budget in group.budgets) budget.id,
  ];

  BudgetProgress? findCategoryBudget(String budgetId) {
    for (final group in categoryGroups) {
      for (final budget in group.budgets) {
        if (budget.id == budgetId) return budget;
      }
    }
    return null;
  }
}
