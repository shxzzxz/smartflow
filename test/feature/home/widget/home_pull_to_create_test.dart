import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/home/widget/home_pull_to_create.dart';

void main() {
  testWidgets('triggers only after the configured pull distance', (
    tester,
  ) async {
    var triggerCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomePullToCreate(
            triggerExtent: 56,
            onTrigger: () => triggerCount++,
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              children: const [SizedBox(height: 200, child: Text('交易'))],
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.text('交易'), const Offset(0, 40));
    await tester.pumpAndSettle();
    expect(triggerCount, 0);

    await tester.drag(find.text('交易'), const Offset(0, 140));
    await tester.pumpAndSettle();
    expect(triggerCount, 1);
  });

  testWidgets('does not trigger while disabled', (tester) async {
    var triggerCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomePullToCreate(
            enabled: false,
            triggerExtent: 56,
            onTrigger: () => triggerCount++,
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              children: const [SizedBox(height: 200, child: Text('交易'))],
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.text('交易'), const Offset(0, 140));
    await tester.pumpAndSettle();

    expect(triggerCount, 0);
  });
}
