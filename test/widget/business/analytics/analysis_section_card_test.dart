import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/widget/business/analytics/analysis_chart_card.dart';
import 'package:smartflow/widget/business/analytics/analysis_section_card.dart';

void main() {
  testWidgets('renders analysis heading, action, and content', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AnalysisSectionCard(
            title: '预算趋势',
            subtitle: '本月',
            onTitleTap: () => tapped = true,
            titleActionIcon: Icons.chevron_right,
            trailing: const Text('设置'),
            child: const Text('图表'),
          ),
        ),
      ),
    );

    expect(find.text('预算趋势'), findsOneWidget);
    expect(find.text('本月'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('图表'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('analysis-section-title-action')),
    );
    expect(tapped, isTrue);
  });

  testWidgets('keeps the expand action hidden by default', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AnalysisChartCard(
            title: '预算趋势',
            chart: const Text('图表'),
            expandedChartBuilder: (height) => const SizedBox(),
          ),
        ),
      ),
    );

    expect(find.byTooltip('横屏查看预算趋势'), findsNothing);
  });

  testWidgets('opens a chart above the app shell without navigation chrome', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final orientationCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          orientationCalls.add(call);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          bottomNavigationBar: const SizedBox(
            key: ValueKey('app-navigation'),
            height: 64,
          ),
          body: Navigator(
            onGenerateRoute:
                (_) => MaterialPageRoute<void>(
                  builder:
                      (_) => AnalysisChartCard(
                        title: '预算趋势',
                        showExpandIcon: true,
                        chart: const SizedBox(
                          width: double.infinity,
                          height: 180,
                          child: Text('竖屏图表'),
                        ),
                        expandedChartBuilder:
                            (height) =>
                                Text('横屏图表 ${height.toStringAsFixed(0)}'),
                      ),
                ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final expandButton = find.byKey(const ValueKey('chart-expand-预算趋势'));
    expect(find.byTooltip('横屏查看预算趋势'), findsOneWidget);
    expect(tester.getSize(expandButton).height, 44);
    expect(
      tester
          .widget<Icon>(
            find.descendant(of: expandButton, matching: find.byType(Icon)),
          )
          .size,
      18,
    );

    await tester.tap(
      find.descendant(of: expandButton, matching: find.byType(GestureDetector)),
    );
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(800, 360);
    await tester.pumpAndSettle();

    expect(find.textContaining('横屏图表'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-navigation')), findsNothing);
    expect(find.text('预算趋势'), findsNothing);
    expect(find.byTooltip('返回'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(orientationCalls.last.arguments, [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(360, 800);
    await tester.pumpAndSettle();
    expect(find.text('竖屏图表'), findsOneWidget);
    expect(orientationCalls.last.arguments, ['DeviceOrientation.portraitUp']);
  });
}
