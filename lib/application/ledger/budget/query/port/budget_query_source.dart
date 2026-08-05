import '../../../../../core/time/month_key.dart';

class BudgetSettingRow {
  const BudgetSettingRow({
    required this.id,
    required this.amountMinor,
    required this.sortOrder,
    this.categoryId,
  });

  final String id;
  final String? categoryId;
  final int amountMinor;
  final int sortOrder;
}

class BudgetCategoryRow {
  const BudgetCategoryRow({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.parentId,
    this.iconKey,
  });

  final String id;
  final String name;
  final String? parentId;
  final String? iconKey;
  final int sortOrder;
}

class BudgetDailyUsageRow {
  const BudgetDailyUsageRow({
    required this.date,
    required this.categoryId,
    required this.amountMinor,
  });

  final DateTime date;
  final String categoryId;
  final int amountMinor;
}

class BudgetQuerySnapshot {
  const BudgetQuerySnapshot({
    required this.budgets,
    required this.categories,
    required this.dailyUsage,
  });

  final List<BudgetSettingRow> budgets;
  final List<BudgetCategoryRow> categories;
  final List<BudgetDailyUsageRow> dailyUsage;
}

abstract interface class BudgetQuerySource {
  Stream<BudgetQuerySnapshot> watchMonth(MonthKey month);
}
