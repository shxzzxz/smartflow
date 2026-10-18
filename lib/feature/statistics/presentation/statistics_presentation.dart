import 'dart:math' as math;

import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../shared/analytics/time_series_transform.dart';

class StatisticsBreakdownItem {
  const StatisticsBreakdownItem({
    required this.id,
    required this.title,
    required this.accountType,
    required this.amount,
    required this.progress,
    this.children = const [],
    this.isUnsubdivided = false,
    this.comparisonAmount,
  });

  /// 分类统计项对应活跃分类 ID（"未细分"项使用一级分类的真实 ID）；
  /// 资产负债明细项对应结算账户 ID。
  final String id;
  final String title;
  final AccountType accountType;
  final Money amount;
  final double progress;
  final List<StatisticsBreakdownItem> children;

  /// 一级分类自身直接金额的"未细分"项；钻取只命中该分类自身，不展开二级。
  final bool isUnsubdivided;
  final Money? comparisonAmount;

  StatisticsBreakdownItem copyWith({
    double? progress,
    List<StatisticsBreakdownItem>? children,
    Money? comparisonAmount,
  }) {
    return StatisticsBreakdownItem(
      id: id,
      title: title,
      accountType: accountType,
      amount: amount,
      progress: progress ?? this.progress,
      children: children ?? this.children,
      isUnsubdivided: isUnsubdivided,
      comparisonAmount: comparisonAmount ?? this.comparisonAmount,
    );
  }
}

typedef StatisticsTimeGrouping = TimeSeriesGranularity;

enum StatisticsCategoryLevel { primary, secondary }

enum _StatisticsSeries { income, expense, assets, liabilities }

extension StatisticsTimeGroupingPresentation on StatisticsTimeGrouping {
  DateTime bucketStart(DateTime date, {required DateTime anchor}) {
    return timeSeriesBucketStart(date, granularity: this, anchor: anchor);
  }

  String labelFor(DateTime start) => switch (this) {
    StatisticsTimeGrouping.day => '${start.month}/${start.day}',
    StatisticsTimeGrouping.week => '${start.month}/${start.day}',
    StatisticsTimeGrouping.month => '${start.month}月',
    StatisticsTimeGrouping.year => '${start.year}',
  };

  String get description => switch (this) {
    StatisticsTimeGrouping.day => '按日汇总，点击柱形查看金额',
    StatisticsTimeGrouping.week => '按 7 天汇总，避免长区间过密',
    StatisticsTimeGrouping.month => '按月汇总，突出长期趋势',
    StatisticsTimeGrouping.year => '按年汇总，突出长期趋势',
  };
}

class StatisticsCashflowBucket {
  const StatisticsCashflowBucket({
    required this.date,
    required this.label,
    required this.incomeMinor,
    required this.expenseMinor,
  });

  final DateTime date;
  final String label;
  final int incomeMinor;
  final int expenseMinor;
}

class StatisticsBalanceTrendBucket {
  const StatisticsBalanceTrendBucket({
    required this.date,
    required this.label,
    required this.assets,
    required this.liabilities,
  });

  final DateTime date;
  final String label;
  final Money assets;
  final Money liabilities;

  Money get netAssets => assets - liabilities;
}

List<StatisticsCashflowBucket> buildStatisticsCashflowBuckets(
  List<DailyCashflowSummary> items, {
  StatisticsTimeGrouping grouping = StatisticsTimeGrouping.day,
}) {
  if (items.isEmpty) {
    return const [];
  }
  final buckets = aggregateMinorTimeSeries(
    [
      for (final item in items)
        MinorTimeSeriesPoint(
          date: item.date,
          values: {
            _StatisticsSeries.income: item.income.minorUnits,
            _StatisticsSeries.expense: item.expense.minorUnits,
          },
        ),
    ],
    granularity: grouping,
    aggregation: TimeSeriesAggregation.flowSum,
  );
  return [
    for (final bucket in buckets)
      StatisticsCashflowBucket(
        date: bucket.start,
        label: grouping.labelFor(bucket.start),
        incomeMinor: bucket.values[_StatisticsSeries.income]!,
        expenseMinor: bucket.values[_StatisticsSeries.expense]!,
      ),
  ];
}

List<StatisticsBalanceTrendBucket> buildStatisticsBalanceTrendBuckets(
  List<BalanceTrendPoint> items, {
  required StatisticsTimeGrouping grouping,
}) {
  if (items.isEmpty) {
    return const [];
  }
  final sorted = [...items]
    ..sort((left, right) => left.date.compareTo(right.date));
  DateTime effectiveDateAt(int index) {
    final snapshotDate = index == 0
        ? sorted[index].date
        : sorted[index].date.subtract(const Duration(days: 1));
    return DateTime(snapshotDate.year, snapshotDate.month, snapshotDate.day);
  }

  final buckets = aggregateMinorTimeSeries(
    [
      for (var index = 0; index < sorted.length; index++)
        MinorTimeSeriesPoint(
          date: effectiveDateAt(index),
          values: {
            _StatisticsSeries.assets: sorted[index].assets.minorUnits,
            _StatisticsSeries.liabilities: sorted[index].liabilities.minorUnits,
          },
        ),
    ],
    granularity: grouping,
    aggregation: TimeSeriesAggregation.periodEnd,
  );
  return [
    for (final bucket in buckets)
      StatisticsBalanceTrendBucket(
        date: bucket.start,
        label: grouping.labelFor(bucket.start),
        assets: Money(minorUnits: bucket.values[_StatisticsSeries.assets]!),
        liabilities: Money(
          minorUnits: bucket.values[_StatisticsSeries.liabilities]!,
        ),
      ),
  ];
}

List<DailyCashflowSummary> fillStatisticsDailyCashflowDates(
  List<DailyCashflowSummary> items, {
  required DateTime from,
  required DateTime until,
}) {
  final byDate = {
    for (final item in items)
      DateTime(item.date.year, item.date.month, item.date.day): item,
  };
  final result = <DailyCashflowSummary>[];
  var date = DateTime(from.year, from.month, from.day);
  while (date.isBefore(until)) {
    result.add(
      byDate[date] ??
          DailyCashflowSummary(
            date: date,
            income: const Money(minorUnits: 0),
            expense: const Money(minorUnits: 0),
          ),
    );
    date = DateTime(date.year, date.month, date.day + 1);
  }
  return result;
}

List<StatisticsBreakdownItem> selectStatisticsCategoryItems(
  List<StatisticsBreakdownItem> primary, {
  required bool secondary,
}) {
  final result = <StatisticsBreakdownItem>[
    ...(secondary ? primary.expand((item) => item.children) : primary),
  ];
  result.sort(_compareBreakdown);
  // 子分类的 progress 原本按各自父分类内归一，扁平后需要跨全表重新归一。
  return secondary ? _withProgress(result) : result;
}

double statisticsCategoryShare(
  StatisticsBreakdownItem item,
  List<StatisticsBreakdownItem> items,
) {
  final total = items.fold<int>(
    0,
    (sum, value) => sum + statisticsCategoryMagnitude(value),
  );
  return total == 0 ? 0 : statisticsCategoryMagnitude(item) / total;
}

int statisticsCategoryMagnitude(StatisticsBreakdownItem item) {
  return item.amount.minorUnits < 0 ? 0 : item.amount.minorUnits;
}

String statisticsCategoryPercentageText(
  StatisticsBreakdownItem item,
  List<StatisticsBreakdownItem> items,
) {
  return '${(statisticsCategoryShare(item, items) * 100).toStringAsFixed(1)}%';
}

String statisticsDateLabel(DateTime date) => '${date.month}/${date.day}';

/// 系列色槽位上限，超出部分折叠为"其他"，系列色不循环复用。
const statisticsSeriesSlotCount = 8;

class StatisticsDonutSlice {
  const StatisticsDonutSlice({
    required this.title,
    required this.valueMinor,
    this.isOther = false,
  });

  final String title;
  final int valueMinor;
  final bool isOther;
}

List<StatisticsDonutSlice> buildStatisticsDonutSlices(
  List<StatisticsBreakdownItem> items,
) {
  return topNWithOther(
    [
      for (final item in items)
        StatisticsDonutSlice(
          title: item.title,
          valueMinor: statisticsCategoryMagnitude(item),
        ),
    ],
    maxItems: statisticsSeriesSlotCount,
    compare: (left, right) => right.valueMinor.compareTo(left.valueMinor),
    buildOther: (tail) => StatisticsDonutSlice(
      title: '其他',
      valueMinor: tail.fold(0, (sum, slice) => sum + slice.valueMinor),
      isOther: true,
    ),
  );
}

class StatisticsCashflowKpis {
  const StatisticsCashflowKpis({
    required this.dailyAverageExpense,
    required this.dailyAverageIncome,
    required this.maxDailyExpense,
  });

  final Money dailyAverageExpense;
  final Money dailyAverageIncome;
  final Money maxDailyExpense;
}

StatisticsCashflowKpis buildStatisticsCashflowKpis(
  List<DailyCashflowSummary> items,
) {
  if (items.isEmpty) {
    return const StatisticsCashflowKpis(
      dailyAverageExpense: Money(minorUnits: 0),
      dailyAverageIncome: Money(minorUnits: 0),
      maxDailyExpense: Money(minorUnits: 0),
    );
  }
  var expenseMinor = 0;
  var incomeMinor = 0;
  var maxExpenseMinor = 0;
  for (final item in items) {
    expenseMinor += item.expense.minorUnits;
    incomeMinor += item.income.minorUnits;
    maxExpenseMinor = math.max(maxExpenseMinor, item.expense.minorUnits);
  }
  return StatisticsCashflowKpis(
    dailyAverageExpense: Money(
      minorUnits: (expenseMinor / items.length).round(),
    ),
    dailyAverageIncome: Money(minorUnits: (incomeMinor / items.length).round()),
    maxDailyExpense: Money(minorUnits: maxExpenseMinor),
  );
}

const statisticsWeekdayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

class StatisticsWeekdayBucket {
  const StatisticsWeekdayBucket({
    required this.weekday,
    required this.label,
    required this.totalExpenseMinor,
    required this.dayCount,
  });

  final int weekday;
  final String label;
  final int totalExpenseMinor;
  final int dayCount;

  /// 按该星期在区间内出现的天数取日均，避免区间长度不整周时高估。
  int get averageExpenseMinor =>
      dayCount == 0 ? 0 : (totalExpenseMinor / dayCount).round();
}

List<StatisticsWeekdayBucket> buildStatisticsWeekdayExpenseBuckets(
  List<DailyCashflowSummary> items,
) {
  final totals = List<int>.filled(7, 0);
  final counts = List<int>.filled(7, 0);
  for (final item in items) {
    final index = item.date.weekday - 1;
    totals[index] += item.expense.minorUnits;
    counts[index] += 1;
  }
  return [
    for (var i = 0; i < 7; i++)
      StatisticsWeekdayBucket(
        weekday: i + 1,
        label: statisticsWeekdayLabels[i],
        totalExpenseMinor: totals[i],
        dayCount: counts[i],
      ),
  ];
}

/// 「未打标签」统计项的展示 ID。它只是统计展示口径，不是持久化实体；
/// 不会与 uuid 生成的标签 ID 冲突。
const untaggedTagItemId = 'untagged';

/// 标签构成读模型已是命名条目，这里只做展示映射与 progress 归一。
List<StatisticsBreakdownItem> statisticsTagBreakdownItems(
  List<TagMetricItem> tags,
  AccountType type, {
  List<TagMetricItem>? comparisonTags,
}) {
  final comparisonAmountById = {
    for (final tag in comparisonTags ?? const <TagMetricItem>[])
      if (tag.accountType == type) tag.tagId ?? untaggedTagItemId: tag.amount,
  };
  final result = [
    for (final tag in tags)
      if (tag.accountType == type)
        StatisticsBreakdownItem(
          id: tag.tagId ?? untaggedTagItemId,
          title: tag.isUntagged ? '未打标签' : tag.name,
          accountType: tag.accountType,
          amount: tag.amount,
          progress: 0,
          comparisonAmount: comparisonTags == null
              ? null
              : comparisonAmountById[tag.tagId ?? untaggedTagItemId] ??
                    const Money(minorUnits: 0),
        ),
  ];
  return _withProgress(result);
}

/// 分类统计读模型已由应用查询层组装为两层结构，这里只做展示映射与
/// progress 归一，不再解析 parentId 或账户快照拼树。
List<StatisticsBreakdownItem> statisticsCategoryBreakdownItems(
  List<CategoryMetricGroup> groups,
  AccountType type, {
  List<CategoryMetricGroup>? comparisonGroups,
}) {
  final comparisonByParentId = {
    for (final group in comparisonGroups ?? const <CategoryMetricGroup>[])
      if (group.accountType == type)
        group.id: {for (final item in group.items) item.id: item.amount},
  };
  final result = [
    for (final group in groups)
      if (group.accountType == type)
        StatisticsBreakdownItem(
          id: group.id,
          title: group.name,
          accountType: group.accountType,
          amount: group.total,
          progress: 0,
          comparisonAmount: comparisonGroups == null
              ? null
              : comparisonByParentId[group.id]?.values.fold<Money>(
                      const Money(minorUnits: 0),
                      (sum, amount) => sum + amount,
                    ) ??
                    const Money(minorUnits: 0),
          children: List.unmodifiable(
            _withProgress([
              for (final item in group.items)
                StatisticsBreakdownItem(
                  id: item.id,
                  title: item.isUnsubdivided ? '未细分' : item.name,
                  accountType: group.accountType,
                  amount: item.amount,
                  progress: 0,
                  isUnsubdivided: item.isUnsubdivided,
                  comparisonAmount: comparisonGroups == null
                      ? null
                      : comparisonByParentId[group.id]?[item.id] ??
                            const Money(minorUnits: 0),
                ),
            ]),
          ),
        ),
  ];
  return _withProgress(result);
}

List<StatisticsBreakdownItem> _withProgress(
  List<StatisticsBreakdownItem> items,
) {
  final maxAmount = items
      .map((item) => item.amount.minorUnits.abs())
      .fold<int>(0, (max, value) => value > max ? value : max);
  return [
    for (final item in items)
      item.copyWith(
        progress: maxAmount == 0 ? 0 : item.amount.minorUnits.abs() / maxAmount,
      ),
  ];
}

int _compareBreakdown(
  StatisticsBreakdownItem left,
  StatisticsBreakdownItem right,
) {
  return right.amount.minorUnits.abs().compareTo(left.amount.minorUnits.abs());
}
