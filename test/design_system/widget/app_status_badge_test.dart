import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_status_badge.dart';

void main() {
  testWidgets('uses compact shared status badge geometry and typography', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AppStatusBadge(label: '进行中', color: Colors.blue),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('进行中'));
    final container = tester.widget<Container>(
      find.ancestor(of: find.text('进行中'), matching: find.byType(Container)),
    );
    expect(text.style?.fontSize, 12);
    expect(text.style?.fontWeight, FontWeight.w400);
    expect(
      container.padding,
      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
    expect(tester.takeException(), isNull);
  });
}
