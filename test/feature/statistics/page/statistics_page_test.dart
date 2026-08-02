import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_date_picker_panel.dart';
import 'package:smartflow/feature/shared/provider/current_date_time_provider.dart';
import 'package:smartflow/feature/statistics/page/statistics_page.dart';
import 'package:smartflow/feature/statistics/presentation/statistics_presentation.dart';
import 'package:smartflow/feature/statistics/view_model/statistics_view_model.dart';
import 'package:smartflow/feature/statistics/widget/statistics_charts.dart';

void main() {
  setUpAll(_loadAppFonts);

  testWidgets('shows a clear statistics hierarchy on a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsPage(tester);

    expect(find.text('统计'), findsNothing);
    expect(find.text('查看收支结构与资产变化'), findsNothing);
    expect(find.text('本期概览'), findsNothing);
    expect(find.text('收支统计'), findsOneWidget);
    expect(find.text('按日汇总，点击柱形查看金额'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // 基线在 Windows 开发机生成，Linux 渲染有像素差，CI 通过 --exclude-tags 跳过
  testWidgets('matches the compact Android phone visual baseline', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundaryKey = GlobalKey();

    await _pumpStatisticsPage(tester, boundaryKey: boundaryKey);
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile('goldens/statistics_page_compact.png'),
    );
  }, tags: ['golden']);

  testWidgets('shows a cashflow empty state when the range has no activity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsPage(
      tester,
      presentation: _presentation(
        dailySummaries: [
          DailyCashflowSummary(
            date: DateTime(2026, 1, 5),
            income: const Money(minorUnits: 0),
            expense: const Money(minorUnits: 0),
          ),
        ],
      ),
    );

    expect(find.text('区间内暂无收支数据'), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
  });

  testWidgets('keeps the category header compact with inline controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsPage(tester);
    await tester.scrollUntilVisible(
      find.text('分类构成'),
      200,
      scrollable: _verticalScrollable().last,
    );

    final kindControl = find.byKey(const ValueKey('statistics-category-kind'));
    final levelControl = find.byKey(const ValueKey('statistics-category-level'));
    expect(kindControl, findsOneWidget);
    expect(levelControl, findsOneWidget);
    expect(tester.getRect(kindControl).right, lessThanOrEqualTo(360));
    expect(tester.getRect(levelControl).right, lessThanOrEqualTo(360));
    expect(find.text('主分类'), findsOneWidget);

    // 金额与占比同时展示，不再提供数值模式开关。
    expect(find.text('金额'), findsNothing);
    expect(find.text('占比'), findsNothing);
    expect(find.text('100.0%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the category header stable with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsPage(tester, textScaler: const TextScaler.linear(1.3));
    await tester.scrollUntilVisible(
      find.text('分类构成'),
      200,
      scrollable: _verticalScrollable().last,
    );

    expect(find.text('主分类'), findsOneWidget);
    expect(find.text('子分类'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps category controls usable at accessibility text sizes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsPage(tester, textScaler: const TextScaler.linear(2));
    await tester.scrollUntilVisible(
      find.text('分类构成'),
      200,
      scrollable: _verticalScrollable().last,
    );

    expect(find.text('主分类'), findsOneWidget);
    expect(find.text('子分类'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selects a custom date range from the period sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsPage(tester);
    expect(find.text('2026.1.1 - 2026.1.31'), findsOneWidget);
    await tester.tap(find.text('2026.1.1 - 2026.1.31'));
    await tester.pumpAndSettle();

    // 粒度切到「日」，模式切到「范围」
    await tester.tap(find.text('月'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('范围'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('上个月'));
    await tester.pumpAndSettle();
    expect(find.text('2025年12月'), findsOneWidget);
    final panel = find.byType(AppDatePickerPanel);
    await tester.tap(find.descendant(of: panel, matching: find.text('10')));
    await tester.pump();
    await tester.tap(find.descendant(of: panel, matching: find.text('12')));
    await tester.pump();
    expect(find.text('2025.12.10 - 2025.12.12'), findsOneWidget);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('2025.12.10 - 2025.12.12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick-selects month and year from the period sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsPage(tester);
    await tester.tap(find.text('2026.1.1 - 2026.1.31'));
    await tester.pumpAndSettle();
    expect(find.text('2026年'), findsOneWidget);
    await tester.tap(find.text('1月'));
    await tester.pumpAndSettle();
    expect(find.text('2026.1.1 - 2026.1.31'), findsOneWidget);

    await tester.tap(find.text('2026.1.1 - 2026.1.31'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('月'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('年'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026'));
    await tester.pumpAndSettle();
    expect(find.text('2026.1.1 - 2026.12.31'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows market-level charts and switches analysis dimensions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpStatisticsPage(tester);

    expect(find.text('2026.1.1 - 2026.1.31'), findsOneWidget);
    expect(find.text('收支统计'), findsOneWidget);
    expect(find.text('累计'), findsNothing);

    final cashflowChart = find.byKey(
      const ValueKey('statistics-cashflow-chart'),
    );
    expect(
      find.descendant(of: cashflowChart, matching: find.byType(BarChart)),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('statistics-cashflow-metric')),
        matching: find.text('对比'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: cashflowChart, matching: find.text('收入')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('statistics-cashflow-settings')),
    );
    await tester.pumpAndSettle();
    expect(find.text('柱状图'), findsOneWidget);
    await tester.tap(find.text('曲线'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: cashflowChart, matching: find.byType(LineChart)),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('分类构成'),
      200,
      scrollable: _verticalScrollable().last,
    );
    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('主分类'), findsOneWidget);
    expect(find.text('子分类'), findsOneWidget);
    expect(find.text('总支出'), findsOneWidget);
    expect(find.text('100.0%'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('支出习惯'),
      200,
      scrollable: _verticalScrollable().last,
    );
    expect(find.byType(StatisticsWeekdayChart), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('分类构成'),
      -200,
      scrollable: _verticalScrollable().last,
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('statistics-category-kind')),
        matching: find.text('收入'),
      ),
    );
    await tester.pump();
    expect(find.text('总收入'), findsOneWidget);
    expect(find.text('工资'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('工资'),
      100,
      scrollable: _verticalScrollable().last,
    );
    await tester.tap(find.text('工资'));
    await tester.pumpAndSettle();
    expect(find.byType(PieChart), findsOneWidget);
  });
}

Finder _verticalScrollable() => find.byWidgetPredicate(
  (widget) =>
      widget is Scrollable &&
      axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
);

Future<void> _loadAppFonts() async {
  final primary = FontLoader('HarmonyOS Sans')..addFont(
    rootBundle.load('assets/fonts/HarmonyOS_Sans/HarmonyOS_Sans_Regular.ttf'),
  );
  final fallback = FontLoader('HarmonyOS Sans SC')..addFont(
    rootBundle.load(
      'assets/fonts/HarmonyOS_Sans_SC/HarmonyOS_Sans_SC_Regular.ttf',
    ),
  );
  final materialIcons = FontLoader('MaterialIcons')
    ..addFont(_loadMaterialIcons());
  final remixIcons = FontLoader('packages/remixicon/remix')
    ..addFont(rootBundle.load('packages/remixicon/fonts/remix.ttf'));
  await Future.wait([
    primary.load(),
    fallback.load(),
    materialIcons.load(),
    remixIcons.load(),
  ]);
}

Future<ByteData> _loadMaterialIcons() async {
  final flutterRoot = _findFlutterRoot();
  final bytes =
      await File(
        path.join(
          flutterRoot.path,
          'bin',
          'cache',
          'artifacts',
          'material_fonts',
          'MaterialIcons-Regular.otf',
        ),
      ).readAsBytes();
  return ByteData.sublistView(bytes);
}

Directory _findFlutterRoot() {
  final configuredRoot = Platform.environment['FLUTTER_ROOT'];
  if (configuredRoot != null) {
    final directory = Directory(configuredRoot);
    if (directory.existsSync()) return directory;
  }

  var directory = Directory.current;
  while (true) {
    final fvmRoot = Directory(path.join(directory.path, '.fvm', 'flutter_sdk'));
    if (fvmRoot.existsSync()) return fvmRoot;
    if (directory.parent.path == directory.path) break;
    directory = directory.parent;
  }

  throw StateError('Unable to locate the Flutter SDK for Material Icons.');
}

Future<void> _pumpStatisticsPage(
  WidgetTester tester, {
  Key? boundaryKey,
  StatisticsPresentation? presentation,
  TextScaler? textScaler,
}) async {
  final month = DateTime(2026, 1);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentDateTimeProvider.overrideWithValue(DateTime(2026, 1, 15)),
        statisticsRangeContentProvider(
          month,
          DateTime(2026, 1, 16),
          1,
        ).overrideWith(
          (ref) => StatisticsContentState.loaded(
            presentation: presentation ?? _presentation(),
          ),
        ),
        statisticsRangeContentProvider(
          DateTime(2025, 12, 10),
          DateTime(2025, 12, 13),
          1,
        ).overrideWith(
          (ref) => StatisticsContentState.loaded(
            presentation: presentation ?? _presentation(),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        builder:
            textScaler == null
                ? null
                : (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                  child: child!,
                ),
        home: RepaintBoundary(key: boundaryKey, child: const StatisticsPage()),
      ),
    ),
  );
  await tester.pump();
}

StatisticsPresentation _presentation({
  List<DailyCashflowSummary>? dailySummaries,
}) {
  return StatisticsPresentation(
    cashflowComparison: const CashflowComparison(
      current: CashflowSummary(
        income: Money(minorUnits: 2000),
        expense: Money(minorUnits: 700),
      ),
      previousSamePeriod: CashflowSummary(
        income: Money(minorUnits: 1000),
        expense: Money(minorUnits: 400),
      ),
      previousFullPeriod: CashflowSummary(
        income: Money(minorUnits: 1000),
        expense: Money(minorUnits: 400),
      ),
    ),
    dailySummaries:
        dailySummaries ??
        [
          DailyCashflowSummary(
            date: DateTime(2026, 1, 5),
            income: const Money(minorUnits: 2000),
            expense: const Money(minorUnits: 700),
          ),
        ],
    incomeCategories: const [
      StatisticsBreakdownItem(
        id: 'salary',
        title: '工资',
        accountIds: {'salary'},
        accountType: AccountType.income,
        amount: Money(minorUnits: 2000),
        progress: 1,
        children: [
          StatisticsBreakdownItem(
            id: 'base-salary',
            title: '基本工资',
            accountIds: {'salary'},
            accountType: AccountType.income,
            amount: Money(minorUnits: 2000),
            progress: 1,
          ),
        ],
      ),
    ],
    expenseCategories: const [
      StatisticsBreakdownItem(
        id: 'food',
        title: '餐饮',
        accountIds: {'dining'},
        accountType: AccountType.expense,
        amount: Money(minorUnits: 700),
        progress: 1,
      ),
    ],
    balanceComparison: const BalanceSheetComparison(
      current: BalanceSheetSnapshot(
        assets: Money(minorUnits: 10000),
        liabilities: Money(minorUnits: 2000),
      ),
      previous: BalanceSheetSnapshot(
        assets: Money(minorUnits: 9000),
        liabilities: Money(minorUnits: 2000),
      ),
    ),
    netAssetTrend: const [],
    balanceAccounts: const [
      StatisticsBreakdownItem(
        id: 'cash',
        title: '现金',
        accountIds: {'cash'},
        accountType: AccountType.asset,
        amount: Money(minorUnits: 10000),
        progress: 1,
      ),
    ],
    cashflowFrom: DateTime(2026, 1),
    cashflowUntil: DateTime(2026, 1, 16),
    balanceUntil: DateTime(2026, 1, 16),
    incomeChangeText: '较上月同期 +10.00',
    expenseChangeText: '较上月同期 +3.00',
    netAssetChangeText: '较上月 +10.00',
    rangeBalanceTrend: [
      BalanceTrendPoint(
        date: DateTime(2026, 1),
        assets: const Money(minorUnits: 10000),
        liabilities: const Money(minorUnits: 2000),
      ),
      BalanceTrendPoint(
        date: DateTime(2026, 1, 15),
        assets: const Money(minorUnits: 11500),
        liabilities: const Money(minorUnits: 2500),
      ),
    ],
  );
}
