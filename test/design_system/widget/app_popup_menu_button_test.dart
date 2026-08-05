import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/token/component.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/design_system/widget/app_popup_menu_button.dart';

void main() {
  testWidgets('keeps a 48dp trigger and a content-sized menu', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: AppPopupMenuButton(
              tooltip: '更多',
              icon: RemixIcons.more_2_fill,
              items: [AppPopupMenuAction(label: '调整分类预算顺序', onPressed: () {})],
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(AppPopupMenuButton)),
      const Size.square(AppSpacing.space48),
    );

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(MenuItemButton)).width,
      greaterThanOrEqualTo(AppComponentTokens.menuMinWidth),
    );
  });

  testWidgets('toggle options update immediately and keep the menu open', (
    tester,
  ) async {
    bool? changedValue;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: AppPopupMenuButton(
              tooltip: '页面设置',
              icon: RemixIcons.settings_3_line,
              items: [
                AppPopupMenuToggle(
                  label: '显示图例',
                  value: false,
                  onChanged: (value) => changedValue = value,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AppPopupMenuButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('显示图例'));
    await tester.pumpAndSettle();

    expect(changedValue, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(find.text('显示图例'), findsOneWidget);
  });

  testWidgets('action options invoke their command and close the menu', (
    tester,
  ) async {
    var invocationCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: AppPopupMenuButton(
              tooltip: '更多',
              icon: RemixIcons.more_2_fill,
              items: [
                AppPopupMenuAction(
                  label: '调整顺序',
                  onPressed: () => invocationCount += 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('调整顺序'));
    await tester.pumpAndSettle();

    expect(invocationCount, 1);
    expect(find.text('调整顺序'), findsNothing);
  });

  testWidgets('action options support a disabled state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Center(
            child: AppPopupMenuButton(
              tooltip: '更多',
              icon: RemixIcons.more_2_fill,
              items: [AppPopupMenuAction(label: '暂不可用', onPressed: null)],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<MenuItemButton>(find.byType(MenuItemButton)).enabled,
      isFalse,
    );
  });

  testWidgets('choice options update their selection and keep the menu open', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) {
                return AppPopupMenuButton(
                  tooltip: '图表设置',
                  icon: RemixIcons.settings_3_line,
                  items: [
                    AppPopupMenuChoice(
                      label: '柱状图',
                      selected: selected == 0,
                      onPressed: () => setState(() => selected = 0),
                    ),
                    AppPopupMenuChoice(
                      label: '曲线',
                      selected: selected == 1,
                      onPressed: () => setState(() => selected = 1),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('图表设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('曲线'));
    await tester.pumpAndSettle();

    expect(selected, 1);
    expect(find.text('曲线'), findsOneWidget);
    expect(find.byIcon(RemixIcons.check_line), findsOneWidget);
    expect(
      tester.getCenter(find.byIcon(RemixIcons.check_line)).dy,
      closeTo(tester.getCenter(find.text('曲线')).dy, 1),
    );
  });

  testWidgets('custom controls remain interactive without closing the menu', (
    tester,
  ) async {
    var selected = '低';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) {
                return AppPopupMenuButton(
                  tooltip: '页面设置',
                  icon: RemixIcons.settings_3_line,
                  items: [
                    AppPopupMenuControl(
                      label: '下拉灵敏度',
                      child: TextButton(
                        onPressed: () => setState(() => selected = '高'),
                        child: Text(selected),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('页面设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('低'));
    await tester.pumpAndSettle();

    expect(find.text('下拉灵敏度'), findsOneWidget);
    expect(find.text('高'), findsOneWidget);
  });
}
