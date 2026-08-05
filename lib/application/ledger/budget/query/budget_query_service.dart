import '../../../../core/money/money.dart';
import '../../../../core/time/month_key.dart';
import 'budget_read_models.dart';
import 'port/budget_query_source.dart';

abstract interface class BudgetQueryService {
  Stream<MonthlyBudgetReport> watchMonthlyReport(MonthKey month);
}

class BudgetQueryServiceImpl implements BudgetQueryService {
  const BudgetQueryServiceImpl(this._source);

  final BudgetQuerySource _source;

  @override
  Stream<MonthlyBudgetReport> watchMonthlyReport(MonthKey month) {
    return _source
        .watchMonth(month)
        .map((snapshot) => _buildReport(month, snapshot));
  }

  MonthlyBudgetReport _buildReport(
    MonthKey month,
    BudgetQuerySnapshot snapshot,
  ) {
    final categoriesById = {
      for (final category in snapshot.categories) category.id: category,
    };
    final childrenByParent = <String, List<String>>{};
    for (final category in snapshot.categories) {
      if (category.parentId case final parentId?) {
        childrenByParent.putIfAbsent(parentId, () => []).add(category.id);
      }
    }

    final totalSetting = _firstWhereOrNull(
      snapshot.budgets,
      (item) => item.categoryId == null,
    );
    final totalBudget =
        totalSetting == null
            ? null
            : _toProgress(
              setting: totalSetting,
              name: '总预算',
              dailyUsage: snapshot.dailyUsage,
            );

    final settingsByRoot = <String, List<BudgetSettingRow>>{};
    for (final setting in snapshot.budgets) {
      final categoryId = setting.categoryId;
      if (categoryId == null) continue;
      final category = categoriesById[categoryId];
      if (category == null) continue;
      final rootId = category.parentId ?? category.id;
      settingsByRoot.putIfAbsent(rootId, () => []).add(setting);
    }

    final groups = <BudgetCategoryGroup>[];
    for (final entry in settingsByRoot.entries) {
      final root = categoriesById[entry.key];
      if (root == null) continue;
      final settings = entry.value..sort(_compareSetting);
      final rootSetting = _firstWhereOrNull(
        settings,
        (item) => item.categoryId == root.id,
      );
      final childSettings = [
        for (final setting in settings)
          if (setting.categoryId != root.id) setting,
      ];
      final rootScope = <String>{root.id, ...?childrenByParent[root.id]};
      groups.add(
        BudgetCategoryGroup(
          id: root.id,
          name: root.name,
          iconKey: root.iconKey,
          sortOrder: settings.first.sortOrder,
          rootBudget:
              rootSetting == null
                  ? null
                  : _toProgress(
                    setting: rootSetting,
                    name: root.name,
                    iconKey: root.iconKey,
                    categoryIds: rootScope,
                    dailyUsage: snapshot.dailyUsage,
                  ),
          childBudgets: [
            for (final setting in childSettings)
              if (categoriesById[setting.categoryId] case final child?)
                _toProgress(
                  setting: setting,
                  name: child.name,
                  iconKey: child.iconKey,
                  categoryIds: {child.id},
                  dailyUsage: snapshot.dailyUsage,
                ),
          ],
        ),
      );
    }
    groups.sort(
      (left, right) =>
          left.sortOrder != right.sortOrder
              ? left.sortOrder.compareTo(right.sortOrder)
              : left.id.compareTo(right.id),
    );
    return MonthlyBudgetReport(
      month: month,
      totalBudget: totalBudget,
      categoryGroups: groups,
    );
  }

  BudgetProgress _toProgress({
    required BudgetSettingRow setting,
    required String name,
    required List<BudgetDailyUsageRow> dailyUsage,
    String? iconKey,
    Set<String>? categoryIds,
  }) {
    final usageByDate = <DateTime, int>{};
    for (final usage in dailyUsage) {
      if (categoryIds != null && !categoryIds.contains(usage.categoryId)) {
        continue;
      }
      final date = DateTime(usage.date.year, usage.date.month, usage.date.day);
      usageByDate.update(
        date,
        (value) => value + usage.amountMinor,
        ifAbsent: () => usage.amountMinor,
      );
    }
    final dates = usageByDate.keys.toList()..sort();
    var cumulative = 0;
    final trend = <BudgetTrendPoint>[];
    for (final date in dates) {
      cumulative += usageByDate[date]!;
      trend.add(
        BudgetTrendPoint(
          date: date,
          spent: Money(minorUnits: cumulative),
          remaining: Money(minorUnits: setting.amountMinor - cumulative),
        ),
      );
    }
    return BudgetProgress(
      id: setting.id,
      categoryId: setting.categoryId,
      name: name,
      iconKey: iconKey,
      budget: Money(minorUnits: setting.amountMinor),
      spent: Money(minorUnits: cumulative),
      sortOrder: setting.sortOrder,
      trend: trend,
    );
  }
}

int _compareSetting(BudgetSettingRow left, BudgetSettingRow right) {
  final order = left.sortOrder.compareTo(right.sortOrder);
  return order != 0 ? order : left.id.compareTo(right.id);
}

T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T item) predicate) {
  for (final item in items) {
    if (predicate(item)) return item;
  }
  return null;
}
