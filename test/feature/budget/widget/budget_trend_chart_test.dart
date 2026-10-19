import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/time/month_key.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/budget/widget/budget_trend_chart.dart';

void main() {
  testWidgets(
    'shows comparison curves by metric and fills visible periods to the longest month',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final month = MonthKey(year: 2026, month: 4);
      final progress = BudgetProgress(
        id: 'total',
        name: '总预算',
        budget: const Money(minorUnits: 100000),
        spent: const Money(minorUnits: 30000),
        sortOrder: 0,
        trend: [
          BudgetTrendPoint(
            date: DateTime(2026, 4, 30),
            spent: const Money(minorUnits: 30000),
            remaining: const Money(minorUnits: 70000),
          ),
        ],
        previousMonthTrend: [
          BudgetTrendPoint(
            date: DateTime(2026, 3, 1),
            spent: const Money(minorUnits: 5000),
            remaining: const Money(minorUnits: 95000),
          ),
          BudgetTrendPoint(
            date: DateTime(2026, 3, 31),
            spent: const Money(minorUnits: 60000),
            remaining: const Money(minorUnits: 40000),
          ),
        ],
        previousYearTrend: [
          BudgetTrendPoint(
            date: DateTime(2025, 4, 15),
            spent: const Money(minorUnits: 20000),
            remaining: const Money(minorUnits: 80000),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: BudgetTrendChart(month: month, progress: progress),
          ),
        ),
      );

      expect(_lineChart(tester).data.lineBarsData, hasLength(2));
      expect(_lineChart(tester).data.lineBarsData.first.spots, hasLength(31));
      expect(
        find.byKey(const ValueKey('budget-trend-legend-budget')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey('budget-trend-legend-previous-month')),
      );
      await tester.pumpAndSettle();

      var chart = _lineChart(tester);
      expect(chart.data.lineBarsData, hasLength(4));
      expect(
        chart.data.lineBarsData.every((bar) => bar.spots.length == 32),
        isTrue,
      );
      expect(chart.data.lineBarsData[3].spots.first.y, 0);
      expect(chart.data.lineBarsData[3].spots[1].y, 50);
      expect(chart.data.lineBarsData[1].spots.last.y, 400);
      final currentRemaining = chart.data.lineBarsData[0].spots;
      final currentSpent = chart.data.lineBarsData[2].spots;
      expect(currentRemaining[30].y, 700);
      expect(currentRemaining[31].y, currentRemaining[30].y);
      expect(currentSpent[30].y, 300);
      expect(currentSpent[31].y, currentSpent[30].y);

      await tester.tap(
        find.byKey(const ValueKey('budget-trend-legend-remaining')),
      );
      await tester.pumpAndSettle();
      expect(_lineChart(tester).data.lineBarsData, hasLength(2));

      await tester.tap(
        find.byKey(const ValueKey('budget-trend-legend-previous-month')),
      );
      await tester.tap(
        find.byKey(const ValueKey('budget-trend-legend-previous-year')),
      );
      await tester.pumpAndSettle();

      chart = _lineChart(tester);
      expect(chart.data.lineBarsData, hasLength(2));
      expect(
        chart.data.lineBarsData.where((bar) => bar.dashArray != null),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

LineChart _lineChart(WidgetTester tester) {
  return tester.widget<LineChart>(find.byType(LineChart));
}
