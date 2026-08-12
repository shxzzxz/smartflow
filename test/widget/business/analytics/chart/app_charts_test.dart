import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/widget/business/analytics/chart/app_donut_chart.dart';
import 'package:smartflow/widget/business/analytics/chart/app_cartesian_chart.dart';

void main() {
  testWidgets('renders line series with a shared legend', (tester) async {
    await tester.pumpWidget(
      _host(
        AppCartesianChart(
          data: AppCartesianChartData(
            axisPoints: const [
              AppChartAxisPoint(x: 0, label: '1日'),
              AppChartAxisPoint(x: 1, label: '2日'),
            ],
            series: const [
              AppChartSeries(
                label: '收入',
                color: Colors.green,
                points: [
                  AppChartPoint(x: 0, value: 10, formattedValue: '¥10'),
                  AppChartPoint(x: 1, value: 20, formattedValue: '¥20'),
                ],
              ),
              AppChartSeries(
                label: '支出',
                color: Colors.red,
                points: [
                  AppChartPoint(x: 0, value: 8, formattedValue: '¥8'),
                  AppChartPoint(x: 1, value: 12, formattedValue: '¥12'),
                ],
              ),
            ],
          ),
          form: AppCartesianChartForm.line,
          showLegend: true,
        ),
      ),
    );

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('收入'), findsOneWidget);
    expect(find.text('支出'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chart-legend-收入')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData,
      hasLength(1),
    );

    await tester.tap(find.byKey(const ValueKey('chart-legend-支出')));
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsNothing);
    expect(find.text('未选择数据系列'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chart-legend-收入')));
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('renders grouped bar series', (tester) async {
    await tester.pumpWidget(
      _host(
        AppCartesianChart(
          data: AppCartesianChartData(
            axisPoints: const [AppChartAxisPoint(x: 0, label: '周一')],
            series: const [
              AppChartSeries(
                label: '日均支出',
                color: Colors.red,
                points: [AppChartPoint(x: 0, value: 8, formattedValue: '¥8')],
              ),
            ],
          ),
          form: AppCartesianChartForm.bar,
        ),
      ),
    );

    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets('toggles grouped bar series from the legend', (tester) async {
    await tester.pumpWidget(
      _host(
        AppCartesianChart(
          data: AppCartesianChartData(
            axisPoints: const [AppChartAxisPoint(x: 0, label: '1日')],
            series: const [
              AppChartSeries(
                label: '收入',
                color: Colors.green,
                points: [AppChartPoint(x: 0, value: 10, formattedValue: '¥10')],
              ),
              AppChartSeries(
                label: '支出',
                color: Colors.red,
                points: [AppChartPoint(x: 0, value: 8, formattedValue: '¥8')],
              ),
            ],
          ),
          form: AppCartesianChartForm.bar,
          showLegend: true,
        ),
      ),
    );

    expect(
      tester
          .widget<BarChart>(find.byType(BarChart))
          .data
          .barGroups
          .single
          .barRods,
      hasLength(2),
    );
    await tester.tap(find.byKey(const ValueKey('chart-legend-支出')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BarChart>(find.byType(BarChart))
          .data
          .barGroups
          .single
          .barRods,
      hasLength(1),
    );

    await tester.pumpWidget(
      _host(
        AppCartesianChart(
          data: AppCartesianChartData(
            axisPoints: const [AppChartAxisPoint(x: 0, label: '1日')],
            series: const [
              AppChartSeries(
                label: '收入',
                color: Colors.green,
                points: [AppChartPoint(x: 0, value: 10, formattedValue: '¥10')],
              ),
              AppChartSeries(
                label: '支出',
                color: Colors.red,
                points: [AppChartPoint(x: 0, value: 8, formattedValue: '¥8')],
              ),
            ],
          ),
          form: AppCartesianChartForm.line,
          showLegend: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData,
      hasLength(1),
    );
  });

  testWidgets('renders a stable empty state when no chart data exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const AppCartesianChart(
          data: AppCartesianChartData(axisPoints: [], series: []),
          form: AppCartesianChartForm.line,
          emptyMessage: '暂无趋势',
        ),
      ),
    );

    expect(find.text('暂无趋势'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('renders donut slices and center summary', (tester) async {
    await tester.pumpWidget(
      _host(
        const AppDonutChart(
          slices: [
            AppDonutSlice(
              label: '餐饮',
              value: 60,
              formattedValue: '¥60',
              color: Colors.red,
            ),
            AppDonutSlice(
              label: '交通',
              value: 40,
              formattedValue: '¥40',
              color: Colors.blue,
            ),
          ],
          centerLabel: '总支出',
          centerValue: '¥100',
        ),
      ),
    );

    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('总支出'), findsOneWidget);
    expect(find.text('¥100'), findsOneWidget);
  });
}

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: Center(child: SizedBox(width: 360, child: child))),
  );
}
