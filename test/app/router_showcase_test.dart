import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/app/router.dart';
import 'package:smartflow/design_system/showcase/design_system_showcase_page.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';

void main() {
  test('shell contains only the five primary destinations', () {
    final shell = appRouter.configuration.routes.whereType<ShellRoute>().single;

    expect(
      shell.routes.whereType<GoRoute>().map((route) => route.path),
      unorderedEquals([
        '/',
        '/calendar',
        '/account',
        '/statistics',
        '/profile',
      ]),
    );
  });

  test('budget detail is nested outside the app shell', () {
    final budgetRoute = appRouter.configuration.routes
        .whereType<GoRoute>()
        .singleWhere((route) => route.path == '/budget');

    expect(budgetRoute.routes.whereType<GoRoute>().map((route) => route.path), [
      ':id',
    ]);
  });

  testWidgets('opens the design-system showcase route in debug builds', (
    tester,
  ) async {
    appRouter.go('/dev/design-system');
    addTearDown(() => appRouter.go('/'));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: appRouter,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DesignSystemShowcasePage), findsOneWidget);
  });
}
