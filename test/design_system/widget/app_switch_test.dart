import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_switch.dart';

void main() {
  testWidgets('keeps a 48dp tap target and reports changes', (tester) async {
    var value = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: AppSwitch(
              value: value,
              onChanged: (nextValue) => value = nextValue,
            ),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(AppSwitch));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));

    await tester.tap(find.byType(AppSwitch));
    expect(value, isTrue);
  });
}
