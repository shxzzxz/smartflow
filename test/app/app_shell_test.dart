import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/app/app_shell.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';

void main() {
  testWidgets('hides bottom navigation on import routes', (tester) async {
    final router = GoRouter(
      initialLocation: '/import',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/import',
              builder: (context, state) => const Text('导入页'),
            ),
            GoRoute(
              path: '/import/process/yimu',
              builder: (context, state) => const Text('导入处理页'),
            ),
            GoRoute(
              path: '/profile/import/preview',
              builder: (context, state) => const Text('导入预览页'),
            ),
            GoRoute(
              path: '/home',
              builder: (context, state) => const Text('普通页面'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();

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
}
