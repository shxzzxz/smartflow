import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_segmented_control.dart';
import 'package:smartflow/design_system/widget/app_sliding_segmented_control.dart';

void main() {
  Future<void> pumpControl(
    WidgetTester tester, {
    required int selected,
    ValueChanged<int>? onChanged,
    TextScaler? textScaler,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder:
            textScaler == null
                ? null
                : (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                  child: child!,
                ),
        home: Scaffold(
          body: Center(
            child: AppSlidingSegmentedControl<int>(
              segments: const [
                AppSegment(value: 0, label: '支出'),
                AppSegment(value: 1, label: '收入'),
                AppSegment(value: 2, label: '对比'),
              ],
              selected: selected,
              onChanged: onChanged ?? (_) {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('stays compact and reports taps on every segment', (
    tester,
  ) async {
    int? tapped;
    await pumpControl(tester, selected: 0, onChanged: (value) => tapped = value);

    expect(
      tester.getSize(find.byType(AppSlidingSegmentedControl<int>)).height,
      lessThan(40),
    );

    await tester.tap(find.text('对比'));
    expect(tapped, 2);
    await tester.tap(find.text('收入'));
    expect(tapped, 1);
  });

  testWidgets('keeps equal-width cells so the thumb aligns with labels', (
    tester,
  ) async {
    await pumpControl(tester, selected: 1);
    await tester.pumpAndSettle();

    final expenseRect = tester.getRect(find.text('支出'));
    final incomeRect = tester.getRect(find.text('收入'));
    final compareRect = tester.getRect(find.text('对比'));
    expect(
      incomeRect.left - expenseRect.left,
      moreOrLessEquals(compareRect.left - incomeRect.left, epsilon: 0.5),
    );
  });

  testWidgets('grows with accessibility text sizes without clipping', (
    tester,
  ) async {
    await pumpControl(
      tester,
      selected: 0,
      textScaler: const TextScaler.linear(2),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(AppSlidingSegmentedControl<int>)).height,
      greaterThan(40),
    );
  });
}
