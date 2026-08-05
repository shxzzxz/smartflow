import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/token/component.dart';
import 'package:smartflow/design_system/widget/app_select.dart';
import 'package:smartflow/design_system/widget/app_settings_row.dart';

void main() {
  testWidgets('settings switch row toggles when its row is tapped', (
    tester,
  ) async {
    var enabled = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppSettingsSwitchRow(
            label: '显示余额',
            description: '在列表中显示账户余额',
            value: enabled,
            onChanged: (value) => enabled = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('显示余额'));

    expect(enabled, isTrue);
  });

  testWidgets('settings select row shows its value and selects an option', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppSettingsSelectRow<int>(
            label: '下拉灵敏度',
            description: '调整首页下拉多远后松开即可新增交易',
            value: selected,
            options: const [
              AppSelectOption(value: 0, label: '灵敏'),
              AppSelectOption(value: 1, label: '标准'),
              AppSelectOption(value: 2, label: '稳妥'),
            ],
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    expect(find.text('下拉灵敏度'), findsOneWidget);
    expect(find.text('灵敏'), findsOneWidget);
    expect(find.byIcon(RemixIcons.arrow_right_s_line), findsOneWidget);

    await tester.tap(find.text('下拉灵敏度'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('稳妥'));

    expect(selected, 2);
  });

  testWidgets('settings select row keeps a 48dp target without description', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppSettingsSelectRow<int>(
            label: '主题',
            value: 0,
            options: const [AppSelectOption(value: 0, label: '跟随系统')],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(AppSettingsSelectRow<int>)).height,
      greaterThanOrEqualTo(AppComponentTokens.controlMinHeight),
    );
  });

  testWidgets('settings select menu aligns to the row end and flips upward', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomLeft,
            child: SizedBox(
              width: 320,
              child: AppSettingsSelectRow<int>(
                label: '下拉灵敏度',
                value: 0,
                options: const [
                  AppSelectOption(value: 0, label: '灵敏'),
                  AppSelectOption(value: 1, label: '标准'),
                  AppSelectOption(value: 2, label: '稳妥'),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final trigger = tester.getRect(find.byType(AppSettingsSelectRow<int>));
    await tester.tap(find.text('下拉灵敏度'));
    await tester.pumpAndSettle();

    final itemFinder = find.byWidgetPredicate(
      (widget) => widget is PopupMenuItem<int>,
    );
    final firstItem = tester.getRect(itemFinder.first);
    final lastItem = tester.getRect(itemFinder.last);
    expect(firstItem.right, closeTo(trigger.right, 1));
    expect(lastItem.bottom, lessThanOrEqualTo(trigger.top));
  });
}
