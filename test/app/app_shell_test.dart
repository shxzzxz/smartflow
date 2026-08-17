import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/app/app_shell.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/home/view_model/home_view_model.dart';

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

void main() {
  testWidgets('hides bottom navigation on import routes', (tester) async {
    final router = _buildRouter('/import');
    addTearDown(router.dispose);

    await _pumpShell(tester, router: router, settings: const AppSettings());

    expect(find.text('导入页'), findsOneWidget);
    expect(find.text('首页'), findsNothing);

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
}
