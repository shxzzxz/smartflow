import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/token/chart.dart';
import 'package:smartflow/feature/statistics/presentation/statistics_presentation.dart';
import 'package:smartflow/feature/statistics/presentation/statistics_state_presentation.dart';
import 'package:smartflow/feature/statistics/view_model/statistics_view_model.dart';
import 'package:smartflow/feature/statistics/widget/statistics_charts.dart';
import 'package:smartflow/widget/business/analytics/chart/app_cartesian_chart.dart';
import 'package:smartflow/widget/business/analytics/chart/app_chart_scale.dart';

void main() {
  test('snaps chart range to clean tick multiples', () {
    final scale = AppChartScale.fromValues([120, 840, 1160], includeZero: true);

    expect(scale.min, 0);
    expect(scale.max, 1500);
    expect(scale.interval, 500);
  });

  test('spans negative and positive values around zero', () {
    final scale = AppChartScale.fromValues([-1234, 2600], includeZero: true);

    expect(scale.min, -2000);
    expect(scale.max, 4000);
    expect(scale.interval, 2000);
    expect(scale.min % scale.interval, 0);
  });

  test('pads a flat series into a readable band', () {
    final scale = AppChartScale.fromValues([5000, 5000]);

    expect(scale.min, lessThan(5000));
    expect(scale.max, greaterThan(5000));
    expect((scale.max - scale.min) / scale.interval, lessThanOrEqualTo(5));
  });

  test('formats axis amounts compactly', () {
    expect(appChartAxisLabel(0), '0');
    expect(appChartAxisLabel(500), '500');
    expect(appChartAxisLabel(-500), '-500');
    expect(appChartAxisLabel(15000), '1.5万');
    expect(appChartAxisLabel(20000), '2万');
    expect(appChartAxisLabel(-25000), '-2.5万');
    expect(appChartAxisLabel(120000000), '1.2亿');
  });

  test('pads a shorter comparison period to the current horizon', () {
    final trend = buildStatisticsComparisonCashflowTrend(
      currentItems: _dailyCashflow(
        DateTime(2026, 7, 1),
        dayCount: 31,
        expenseMinor: 100,
      ),
      currentFrom: DateTime(2026, 7, 1),
      currentUntil: DateTime(2026, 8, 1),
      comparisonItems: _dailyCashflow(
        DateTime(2026, 6, 1),
        dayCount: 30,
        expenseMinor: 100,
      ),
      comparisonFrom: DateTime(2026, 6, 1),
      comparisonUntil: DateTime(2026, 7, 1),
      grouping: StatisticsTimeGrouping.day,
    );

    expect(trend.current, hasLength(31));
    expect(trend.comparison, hasLength(31));
    expect(trend.current.last.expenseMinor, 3100);
    expect(trend.comparison[29].expenseMinor, 3000);
    expect(trend.comparison.last.expenseMinor, 3000);
  });

  test('samples comparison values by elapsed day across calendar months', () {
    final trend = buildStatisticsComparisonCashflowTrend(
      currentItems: _dailyCashflow(
        DateTime(2026, 1, 31),
        dayCount: 243,
        expenseMinor: 1,
      ),
      currentFrom: DateTime(2026, 1, 31),
      currentUntil: DateTime(2026, 10, 1),
      comparisonItems: _dailyCashflow(
        DateTime(2025, 6, 2),
        dayCount: 243,
        expenseMinor: 1,
      ),
      comparisonFrom: DateTime(2025, 6, 2),
      comparisonUntil: DateTime(2026, 1, 31),
      grouping: StatisticsTimeGrouping.month,
    );

    expect(trend.current, hasLength(9));
    expect(trend.comparison, hasLength(9));
    expect(trend.current.first.expenseMinor, 1);
    expect(trend.comparison.first.expenseMinor, 1);
    expect(trend.current.last.expenseMinor, 243);
    expect(trend.comparison.last.expenseMinor, 243);
  });

  test(
    'pads a shorter current period without dropping the comparison tail',
    () {
      final trend = buildStatisticsComparisonCashflowTrend(
        currentItems: _dailyCashflow(
          DateTime(2026, 4, 1),
          dayCount: 30,
          expenseMinor: 1,
        ),
        currentFrom: DateTime(2026, 4, 1),
        currentUntil: DateTime(2026, 5, 1),
        comparisonItems: _dailyCashflow(
          DateTime(2026, 3, 1),
          dayCount: 31,
          expenseMinor: 1,
        ),
        comparisonFrom: DateTime(2026, 3, 1),
        comparisonUntil: DateTime(2026, 4, 1),
        grouping: StatisticsTimeGrouping.day,
      );

      expect(trend.current.last.expenseMinor, 30);
      expect(trend.comparison.last.expenseMinor, 31);
    },
  );

  test('limits adaptive axis labels by available chart width', () {
    expect(AppChartGeometry.adaptiveAxisLabelLimit(320), 5);
    expect(AppChartGeometry.adaptiveAxisLabelLimit(800), 10);
    expect(AppChartGeometry.adaptiveAxisLabelLimit(40), 2);
  });

  testWidgets('uses finer cashflow buckets when the chart gets wider', (
    tester,
  ) async {
    final from = DateTime(2026, 1, 1);
    final until = DateTime(2027, 1, 1);
    final summaries = [
      for (var index = 0; index < 365; index++)
        DailyCashflowSummary(
          date: DateTime(2026, 1, 1).add(Duration(days: index)),
          income: Money(minorUnits: index == 0 ? 100 : 0),
          expense: const Money(minorUnits: 0),
        ),
    ];

    Future<int> axisPointCount(
      double width, {
      CashflowChartForm form = CashflowChartForm.line,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: StatisticsCashflowChart(
                  from: from,
                  until: until,
                  dailySummaries: summaries,
                  form: form,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester
          .widget<AppCartesianChart>(find.byType(AppCartesianChart))
          .data
          .axisPoints
          .length;
    }

    expect(await axisPointCount(320), 12);
    expect(await axisPointCount(800), 53);
    expect(await axisPointCount(500), 53);
    expect(await axisPointCount(500, form: CashflowChartForm.bar), 12);
  });

  testWidgets('re-resolves granularity for the same widget after resizing', (
    tester,
  ) async {
    final width = ValueNotifier<double>(320);
    addTearDown(width.dispose);
    final from = DateTime(2026, 1, 1);
    final until = DateTime(2027, 1, 1);
    final summaries = [
      for (var index = 0; index < 365; index++)
        DailyCashflowSummary(
          date: DateTime(2026, 1, 1).add(Duration(days: index)),
          income: Money(minorUnits: index == 0 ? 100 : 0),
          expense: const Money(minorUnits: 0),
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: ValueListenableBuilder<double>(
              valueListenable: width,
              builder: (context, value, child) =>
                  SizedBox(width: value, child: child),
              child: StatisticsCashflowChart(
                from: from,
                until: until,
                dailySummaries: summaries,
                form: CashflowChartForm.line,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AppCartesianChart>(find.byType(AppCartesianChart))
          .data
          .axisPoints,
      hasLength(12),
    );

    width.value = 800;
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AppCartesianChart>(find.byType(AppCartesianChart))
          .data
          .axisPoints,
      hasLength(53),
    );
  });

  testWidgets('uses short years on cross-year labels and full tooltip dates', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: StatisticsCashflowChart(
                from: DateTime(2025, 12, 31),
                until: DateTime(2026, 1, 3),
                dailySummaries: _dailyCashflow(
                  DateTime(2025, 12, 31),
                  dayCount: 3,
                  expenseMinor: 100,
                ),
                form: CashflowChartForm.line,
              ),
            ),
          ),
        ),
      ),
    );

    final points = tester
        .widget<AppCartesianChart>(find.byType(AppCartesianChart))
        .data
        .axisPoints;
    expect(points.map((point) => point.label), [
      '25/12/31',
      '26/1/1',
      '26/1/2',
    ]);
    expect(points.map((point) => point.tooltipLabel), [
      '2025/12/31',
      '2026/1/1',
      '2026/1/2',
    ]);
  });

  testWidgets('renders the padded comparison series on the current axis', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: StatisticsComparisonTrendChart(
                from: DateTime(2026, 7, 1),
                until: DateTime(2026, 8, 1),
                comparisonFrom: DateTime(2026, 6, 1),
                comparisonUntil: DateTime(2026, 7, 1),
                currentDailySummaries: _dailyCashflow(
                  DateTime(2026, 7, 1),
                  dayCount: 31,
                  expenseMinor: 100,
                ),
                comparisonDailySummaries: _dailyCashflow(
                  DateTime(2026, 6, 1),
                  dayCount: 30,
                  expenseMinor: 100,
                ),
                metric: StatisticsComparisonMetric.expense,
                comparisonLabel: '环比',
              ),
            ),
          ),
        ),
      ),
    );

    final data = tester
        .widget<AppCartesianChart>(find.byType(AppCartesianChart))
        .data;
    expect(data.axisPoints, hasLength(31));
    expect(data.series.map((series) => series.points.length), [31, 31]);
    expect(data.series.first.points.last.value, 31);
    expect(data.series.last.points.last.value, 30);
  });

  testWidgets('renders principal and interest as separate installment bars', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StatisticsInstallmentCashflowChart(
            months: [
              StatisticsInstallmentCashflowMonth(
                month: DateTime(2026, 1),
                principal: const Money(minorUnits: 10000),
                interest: const Money(minorUnits: 1200),
                fee: const Money(minorUnits: 0),
                total: const Money(minorUnits: 11200),
              ),
            ],
          ),
        ),
      ),
    );

    final chart = tester.widget<AppCartesianChart>(
      find.byType(AppCartesianChart),
    );
    expect(chart.form, AppCartesianChartForm.bar);
    expect(chart.data.series.map((series) => series.label), ['待还本金', '待还利息']);
    expect(chart.data.series.first.points.single.value, 100);
    expect(chart.data.series.last.points.single.value, 12);
  });
}

List<DailyCashflowSummary> _dailyCashflow(
  DateTime from, {
  required int dayCount,
  int expenseMinor = 0,
  int incomeMinor = 0,
}) {
  return [
    for (var index = 0; index < dayCount; index++)
      DailyCashflowSummary(
        date: DateTime(from.year, from.month, from.day + index),
        income: Money(minorUnits: incomeMinor),
        expense: Money(minorUnits: expenseMinor),
      ),
  ];
}
