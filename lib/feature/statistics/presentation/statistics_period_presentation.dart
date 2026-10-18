import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import 'statistics_presentation.dart';

class StatisticsOverviewPresentation {
  const StatisticsOverviewPresentation({
    required this.cashflowComparison,
    required this.kpis,
  });

  final CashflowComparison cashflowComparison;
  final StatisticsCashflowKpis kpis;
}

class StatisticsCashflowTrendPresentation {
  const StatisticsCashflowTrendPresentation({
    required this.from,
    required this.until,
    required this.dailySummaries,
  });

  final DateTime from;
  final DateTime until;
  final List<DailyCashflowSummary> dailySummaries;
}

class StatisticsCategoryAnalysisPresentation {
  const StatisticsCategoryAnalysisPresentation({
    required this.from,
    required this.until,
    required this.comparisonLabel,
    required this.incomeCategories,
    required this.expenseCategories,
  });

  final DateTime from;
  final DateTime until;
  final String? comparisonLabel;
  final List<StatisticsBreakdownItem> incomeCategories;
  final List<StatisticsBreakdownItem> expenseCategories;
}

class StatisticsTagAnalysisPresentation {
  const StatisticsTagAnalysisPresentation({
    required this.from,
    required this.until,
    required this.comparisonLabel,
    required this.incomeTags,
    required this.expenseTags,
  });

  final DateTime from;
  final DateTime until;
  final String? comparisonLabel;
  final List<StatisticsBreakdownItem> incomeTags;
  final List<StatisticsBreakdownItem> expenseTags;
}

class StatisticsBalanceTrendPresentation {
  const StatisticsBalanceTrendPresentation({required this.points});

  final List<BalanceTrendPoint> points;
}

class StatisticsComparisonPresentation {
  const StatisticsComparisonPresentation({
    required this.label,
    required this.from,
    required this.until,
    required this.cashflow,
    required this.dailySummaries,
  });

  final String label;
  final DateTime from;
  final DateTime until;
  final CashflowSummary cashflow;
  final List<DailyCashflowSummary> dailySummaries;

  Money get net => cashflow.income - cashflow.expense;
}

String formatStatisticsRangeLabel(DateTime from, DateTime untilExclusive) {
  final last = untilExclusive.subtract(const Duration(days: 1));
  final start = '${from.year}.${from.month}.${from.day}';
  final end = from.year == last.year
      ? '${last.month}.${last.day}'
      : '${last.year}.${last.month}.${last.day}';
  return '$start - $end';
}

String statisticsComparisonChangePrefix(String comparisonLabel) {
  return comparisonLabel == '环比' || comparisonLabel == '同比'
      ? comparisonLabel
      : '较$comparisonLabel';
}

StatisticsCashflowTrendPresentation buildStatisticsCashflowTrend(
  StatisticsRangeReport report,
) {
  return StatisticsCashflowTrendPresentation(
    from: report.from,
    until: report.until,
    dailySummaries: fillStatisticsDailyCashflowDates(
      report.dailySummaries,
      from: report.from,
      until: report.until,
    ),
  );
}

StatisticsOverviewPresentation buildStatisticsOverview(
  StatisticsRangeReport report, {
  required List<DailyCashflowSummary> dailySummaries,
}) {
  final comparisonCashflow =
      report.comparison?.cashflow ??
      const CashflowSummary(
        income: Money(minorUnits: 0),
        expense: Money(minorUnits: 0),
      );
  return StatisticsOverviewPresentation(
    cashflowComparison: CashflowComparison(
      current: report.cashflow,
      previousSamePeriod: comparisonCashflow,
      previousFullPeriod: comparisonCashflow,
    ),
    kpis: buildStatisticsCashflowKpis(dailySummaries),
  );
}

StatisticsComparisonPresentation? buildStatisticsComparison(
  StatisticsRangeReport report, {
  required String? label,
}) {
  final comparison = report.comparison;
  if (comparison == null) return null;
  return StatisticsComparisonPresentation(
    label: label ?? '对比期',
    from: comparison.from,
    until: comparison.until,
    cashflow: comparison.cashflow,
    dailySummaries: fillStatisticsDailyCashflowDates(
      comparison.dailySummaries,
      from: comparison.from,
      until: comparison.until,
    ),
  );
}

StatisticsCategoryAnalysisPresentation buildStatisticsCategoryAnalysis(
  StatisticsRangeReport report, {
  required String? comparisonLabel,
}) {
  return StatisticsCategoryAnalysisPresentation(
    from: report.from,
    until: report.until,
    comparisonLabel: comparisonLabel,
    incomeCategories: statisticsCategoryBreakdownItems(
      report.categories,
      AccountType.income,
      comparisonGroups: report.comparison?.categories,
    ),
    expenseCategories: statisticsCategoryBreakdownItems(
      report.categories,
      AccountType.expense,
      comparisonGroups: report.comparison?.categories,
    ),
  );
}

StatisticsTagAnalysisPresentation buildStatisticsTagAnalysis(
  StatisticsRangeReport report, {
  required String? comparisonLabel,
}) {
  return StatisticsTagAnalysisPresentation(
    from: report.from,
    until: report.until,
    comparisonLabel: comparisonLabel,
    incomeTags: statisticsTagBreakdownItems(
      report.tags,
      AccountType.income,
      comparisonTags: report.comparison?.tags,
    ),
    expenseTags: statisticsTagBreakdownItems(
      report.tags,
      AccountType.expense,
      comparisonTags: report.comparison?.tags,
    ),
  );
}

StatisticsBalanceTrendPresentation buildStatisticsBalanceTrend(
  StatisticsRangeReport report,
) {
  return StatisticsBalanceTrendPresentation(points: report.balanceTrend);
}
