import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/app/app_shell.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/token/component.dart';
import 'package:smartflow/design_system/widget/app_bottom_navigation_layout_scope.dart';
import 'package:smartflow/feature/home/view_model/home_view_model.dart';
import 'package:smartflow/feature/home/widget/home_transaction_filter_sheet.dart';
import 'package:smartflow/feature/statistics/view_model/statistics_view_model.dart';
import 'package:smartflow/feature/statistics/widget/statistics_comparison_sheet.dart';
import 'package:smartflow/feature/statistics/widget/statistics_period_sheet.dart';

class _FakeAppSettingsStore implements AppSettingsStore {
  _FakeAppSettingsStore(this.settings);

  AppSettings settings;

  @override
  Future<AppSettings> read() async => settings;

  @override
  Future<void> save(AppSettings settings) async {
    this.settings = settings;
  }
}

GoRouter _buildRouter(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const Text('普通页面'),
          ),
        ],
      ),
      GoRoute(path: '/import', builder: (context, state) => const Text('导入页')),
      GoRoute(
        path: '/import/process/yimu',
        builder: (context, state) => const Text('导入处理页'),
      ),
      GoRoute(
        path: '/profile/import/preview',
        builder: (context, state) => const Text('导入预览页'),
      ),
    ],
  );
}

GoRouter _buildSheetRouter(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const _HomeFilterEntryPage(),
          ),
          GoRoute(
            path: '/statistics',
            builder: (context, state) => const _StatisticsSheetEntryPage(),
          ),
          GoRoute(
            path: '/account',
            builder: (context, state) => const Text('资产页'),
          ),
        ],
      ),
    ],
  );
}

Future<void> _pumpShell(
  WidgetTester tester, {
  required GoRouter router,
  required AppSettings settings,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSettingsStoreProvider.overrideWithValue(
          _FakeAppSettingsStore(settings),
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class _HomeFilterEntryPage extends StatelessWidget {
  const _HomeFilterEntryPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          key: const ValueKey('open-home-filter'),
          onPressed: () {
            showHomeTransactionFilterSheet(
              context: context,
              initialFilter: const HomeTransactionFilter.all(),
              expenseTree: const [],
              incomeTree: const [],
              accounts: const [],
            );
          },
          child: const Text('打开筛选'),
        ),
      ),
    );
  }
}

class _StatisticsSheetEntryPage extends StatelessWidget {
  const _StatisticsSheetEntryPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              key: const ValueKey('open-statistics-period'),
              onPressed: () async {
                await showStatisticsPeriodSheet(
                  context: context,
                  granularity: StatisticsPeriodGranularity.month,
                  mode: StatisticsPeriodMode.single,
                  from: DateTime(2026, 10),
                  untilExclusive: DateTime(2026, 11),
                  lastSelectableDate: DateTime(2026, 10, 20),
                );
              },
              child: const Text('选择统计周期'),
            ),
            TextButton(
              key: const ValueKey('open-statistics-comparison'),
              onPressed: () async {
                await showStatisticsComparisonSheet(
                  context: context,
                  selected: StatisticsComparisonMode.none,
                  automatic: null,
                  previousYear: null,
                );
              },
              child: const Text('设置对比时间'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _expectSheetBlocksNavigation({
  required WidgetTester tester,
  required BottomNavigationStyle style,
  required String initialLocation,
  required Key openButtonKey,
}) async {
  final router = _buildSheetRouter(initialLocation);
  addTearDown(router.dispose);

  await _pumpShell(
    tester,
    router: router,
    settings: AppSettings(bottomNavigationStyle: style),
  );

  await tester.tap(find.byKey(openButtonKey));
  await tester.pumpAndSettle();
  expect(find.byType(BottomSheet), findsOneWidget);

  final navigationKey = switch (style) {
    BottomNavigationStyle.classic => const ValueKey(
      'classic-bottom-navigation',
    ),
    BottomNavigationStyle.frostedGlass => const ValueKey(
      'frosted-glass-bottom-navigation',
    ),
  };
  await tester.tapAt(tester.getCenter(find.byKey(navigationKey)));
  await tester.pumpAndSettle();

  expect(find.text('资产页'), findsNothing);
}

void main() {
  testWidgets('hides bottom navigation on import routes', (tester) async {
    final router = _buildRouter('/import');
    addTearDown(router.dispose);

    await _pumpShell(tester, router: router, settings: const AppSettings());

    expect(find.text('导入页'), findsOneWidget);
    expect(find.text('首页'), findsNothing);
    expect(
      find.byKey(const ValueKey('classic-bottom-navigation')),
      findsNothing,
    );

    router.go('/import/process/yimu');
    await tester.pumpAndSettle();
    expect(find.text('导入处理页'), findsOneWidget);
    expect(find.text('首页'), findsNothing);

    router.go('/profile/import/preview');
    await tester.pumpAndSettle();
    expect(find.text('导入预览页'), findsOneWidget);
    expect(find.text('首页'), findsNothing);

    router.go('/home');
    await tester.pumpAndSettle();
    expect(find.text('普通页面'), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('classic-bottom-navigation')),
      findsOneWidget,
    );
    final classicScaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final classicLayout = tester
        .widget<AppBottomNavigationLayoutScope>(
          find.byType(AppBottomNavigationLayoutScope),
        )
        .layout;
    expect(classicScaffold.extendBody, isTrue);
    expect(classicLayout.contentInset, AppComponentTokens.navigationBarHeight);
    expect(
      classicLayout.floatingActionInset,
      AppComponentTokens.navigationBarHeight,
    );
  });

  testWidgets('hides navigation labels when disabled in settings', (
    tester,
  ) async {
    final router = _buildRouter('/home');
    addTearDown(router.dispose);

    await _pumpShell(
      tester,
      router: router,
      settings: const AppSettings(showBottomNavLabels: false),
    );

    expect(find.text('普通页面'), findsOneWidget);
    expect(find.byIcon(RemixIcons.home_4_fill), findsOneWidget);
    expect(find.text('首页'), findsNothing);
    expect(find.text('我的'), findsNothing);
  });

  testWidgets('hides bottom navigation while home batch mode is active', (
    tester,
  ) async {
    final router = _buildRouter('/home');
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsStoreProvider.overrideWithValue(
            _FakeAppSettingsStore(const AppSettings()),
          ),
          homeBatchModeProvider.overrideWithValue(true),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('普通页面'), findsOneWidget);
    expect(find.text('首页'), findsNothing);
  });

  testWidgets('renders a floating frosted glass navigation bar', (
    tester,
  ) async {
    final router = _buildRouter('/home');
    addTearDown(router.dispose);

    await _pumpShell(
      tester,
      router: router,
      settings: const AppSettings(
        bottomNavigationStyle: BottomNavigationStyle.frostedGlass,
      ),
    );

    expect(
      find.byKey(const ValueKey('frosted-glass-bottom-navigation')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('classic-bottom-navigation')),
      findsNothing,
    );
    final backdropFilter = tester
        .widget<BackdropFilter>(find.byType(BackdropFilter))
        .filter;
    expect(
      backdropFilter,
      ImageFilter.compose(
        outer: ColorFilter.saturation(
          AppComponentTokens.frostedNavigationBarSaturation,
        ),
        inner: ImageFilter.blur(
          sigmaX: AppComponentTokens.frostedNavigationBarBlurSigma,
          sigmaY: AppComponentTokens.frostedNavigationBarBlurSigma,
        ),
      ),
    );
    expect(find.text('首页'), findsOneWidget);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).extendBody, isTrue);
    final frostedClip = tester.widget<ClipRRect>(
      find.descendant(
        of: find.byKey(const ValueKey('frosted-glass-bottom-navigation')),
        matching: find.byType(ClipRRect),
      ),
    );
    expect(
      frostedClip.borderRadius,
      BorderRadius.circular(AppComponentTokens.frostedNavigationBarRadius),
    );
    final frostedLayout = tester
        .widget<AppBottomNavigationLayoutScope>(
          find.byType(AppBottomNavigationLayoutScope),
        )
        .layout;
    expect(
      frostedLayout.contentInset,
      AppComponentTokens.frostedNavigationBarClearance,
    );
    expect(
      frostedLayout.floatingActionInset,
      AppComponentTokens.frostedNavigationBarClearance,
    );
  });

  final sheetEntries = [
    (
      name: 'home filter',
      initialLocation: '/home',
      openButtonKey: const ValueKey('open-home-filter'),
    ),
    (
      name: 'statistics period',
      initialLocation: '/statistics',
      openButtonKey: const ValueKey('open-statistics-period'),
    ),
    (
      name: 'statistics comparison',
      initialLocation: '/statistics',
      openButtonKey: const ValueKey('open-statistics-comparison'),
    ),
  ];
  for (final style in BottomNavigationStyle.values) {
    for (final entry in sheetEntries) {
      testWidgets('${entry.name} sheet blocks ${style.name} navigation', (
        tester,
      ) async {
        await _expectSheetBlocksNavigation(
          tester: tester,
          style: style,
          initialLocation: entry.initialLocation,
          openButtonKey: entry.openButtonKey,
        );
      });
    }
  }
}
