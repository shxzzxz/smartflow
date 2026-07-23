import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/router.dart';
import 'package:smartflow/design_system/showcase/design_system_showcase_page.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';

void main() {
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
