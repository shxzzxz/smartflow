import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/statistics/presentation/statistics_presentation.dart';
import 'package:smartflow/feature/statistics/presentation/statistics_state_presentation.dart';
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

  test('accumulates comparison buckets from the start of the period', () {
    final buckets = buildStatisticsCumulativeCashflowBuckets([
      DailyCashflowSummary(
        date: DateTime(2026, 1, 1),
        income: const Money(minorUnits: 1000),
        expense: const Money(minorUnits: 200),
      ),
      DailyCashflowSummary(
        date: DateTime(2026, 1, 2),
        income: const Money(minorUnits: 500),
        expense: const Money(minorUnits: 300),
      ),
    ], grouping: StatisticsTimeGrouping.day);

    expect(buckets.map((bucket) => bucket.incomeMinor), [1000, 1500]);
    expect(buckets.map((bucket) => bucket.expenseMinor), [200, 500]);
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
