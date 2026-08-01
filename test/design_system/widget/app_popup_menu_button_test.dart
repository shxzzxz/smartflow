import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/token/component.dart';
import 'package:smartflow/design_system/widget/app_popup_menu_button.dart';

void main() {
  Future<void> pumpMenu(
    WidgetTester tester, {
    int? selected,
    ValueChanged<int>? onSelected,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: AppPopupMenuButton<int>(
              tooltip: '图表设置',
              icon: RemixIcons.settings_3_line,
              selected: selected,
              onSelected: onSelected ?? (_) {},
              options: const [
                AppPopupMenuOption(
                  value: 0,
                  label: '柱状图',
                  icon: RemixIcons.bar_chart_line,
                ),
                AppPopupMenuOption(
                  value: 1,
                  label: '曲线',
                  icon: RemixIcons.line_chart_line,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('keeps the trigger compact but the menu content-sized', (
    tester,
  ) async {
    int? tapped;
    await pumpMenu(tester, selected: 1, onSelected: (value) => tapped = value);

    expect(
      tester.getSize(find.byType(AppPopupMenuButton<int>)).height,
      lessThanOrEqualTo(40),
    );

    await tester.tap(find.byType(AppPopupMenuButton<int>));
    await tester.pumpAndSettle();

    // 菜单宽度由内容与最小宽度决定，不受触发按钮尺寸约束。
    expect(
      tester.getSize(find.widgetWithText(PopupMenuItem<int>, '柱状图')).width,
      greaterThanOrEqualTo(AppComponentTokens.menuMinWidth),
    );

    await tester.tap(find.text('柱状图'));
    await tester.pumpAndSettle();
    expect(tapped, 0);
  });

  testWidgets('marks the selected option only in single-select menus', (
    tester,
  ) async {
    await pumpMenu(tester, selected: 1);
    await tester.tap(find.byType(AppPopupMenuButton<int>));
    await tester.pumpAndSettle();

    expect(find.byIcon(RemixIcons.check_line), findsOneWidget);
    final checkX = tester.getCenter(find.byIcon(RemixIcons.check_line)).dx;
    final labelX = tester.getCenter(find.text('曲线')).dx;
    expect(checkX, greaterThan(labelX));
  });

  testWidgets('omits check marks for action menus', (tester) async {
    await pumpMenu(tester);
    await tester.tap(find.byType(AppPopupMenuButton<int>));
    await tester.pumpAndSettle();

    expect(find.text('柱状图'), findsOneWidget);
    expect(find.byIcon(RemixIcons.check_line), findsNothing);
  });
}
