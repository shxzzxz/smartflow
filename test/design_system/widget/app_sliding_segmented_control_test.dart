import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_header_select_button.dart';
import 'package:smartflow/design_system/widget/app_sliding_segmented_control.dart';

void main() {
  Future<void> pumpControl(
    WidgetTester tester, {
    required int selected,
    ValueChanged<int>? onChanged,
    TextScaler? textScaler,
    bool enabled = true,
    double? width,
    AppSegmentedControlVariant variant = AppSegmentedControlVariant.filled,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: textScaler == null
            ? null
            : (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: child!,
              ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: AppSlidingSegmentedControl<int>(
                variant: variant,
                segments: const [
                  AppSegment(value: 0, label: '支出'),
                  AppSegment(value: 1, label: '收入'),
                  AppSegment(value: 2, label: '对比'),
                ],
                selected: selected,
                onChanged: enabled ? onChanged ?? (_) {} : null,
              ),
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
    await pumpControl(
      tester,
      selected: 0,
      onChanged: (value) => tapped = value,
    );

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

  testWidgets('supports keyboard selection', (tester) async {
    int? tapped;
    await pumpControl(
      tester,
      selected: 0,
      onChanged: (value) => tapped = value,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    expect(tapped, 1);
  });

  testWidgets('keeps selected semantics and disables interaction', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      int? tapped;
      await pumpControl(
        tester,
        selected: 0,
        enabled: false,
        onChanged: (value) => tapped = value,
      );

      expect(
        tester.getSemantics(find.text('支出')),
        matchesSemantics(
          label: '支出',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      await tester.tap(find.text('收入'));
      expect(tapped, isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('fits five filter options on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? selected;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppSlidingSegmentedControl<int>(
                segments: const [
                  AppSegment(value: 0, label: '全部'),
                  AppSegment(value: 1, label: '调试'),
                  AppSegment(value: 2, label: '信息'),
                  AppSegment(value: 3, label: '警告'),
                  AppSegment(value: 4, label: '错误'),
                ],
                selected: 0,
                onChanged: (value) => selected = value,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(AppSlidingSegmentedControl<int>)).width,
      lessThanOrEqualTo(280),
    );
    await tester.tap(find.text('错误'));
    expect(selected, 4);
  });

  testWidgets('adaptive header uses the available width and text size', (
    tester,
  ) async {
    int? picked;
    await pumpControl(
      tester,
      selected: 1,
      width: 150,
      variant: AppSegmentedControlVariant.adaptiveHeader,
    );
    expect(find.byType(AppHeaderSelectButton<int>), findsNothing);
    expect(find.text('支出'), findsOneWidget);

    await pumpControl(
      tester,
      selected: 1,
      width: 150,
      textScaler: const TextScaler.linear(2),
      variant: AppSegmentedControlVariant.adaptiveHeader,
      onChanged: (value) => picked = value,
    );
    expect(find.byType(AppHeaderSelectButton<int>), findsOneWidget);
    expect(find.text('支出'), findsNothing);
    await tester.tap(find.byType(AppHeaderSelectButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('对比'));
    await tester.pumpAndSettle();
    expect(picked, 2);
    expect(find.byType(MenuItemButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled adaptive dropdown does not open', (tester) async {
    await pumpControl(
      tester,
      selected: 1,
      width: 90,
      enabled: false,
      variant: AppSegmentedControlVariant.adaptiveHeader,
    );
    expect(find.byType(AppHeaderSelectButton<int>), findsOneWidget);
    await tester.tap(find.byType(AppHeaderSelectButton<int>));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
