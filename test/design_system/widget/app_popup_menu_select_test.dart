import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_popup_menu_button.dart';
import 'package:smartflow/design_system/widget/app_select.dart';

void main() {
  testWidgets('selects an option without closing the settings menu', (
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
                  tooltip: '页面设置',
                  icon: RemixIcons.settings_3_line,
                  items: [
                    AppPopupMenuSelect<int>(
                      label: '下拉灵敏度',
                      value: selected,
                      options: const [
                        AppSelectOption(value: 0, label: '灵敏'),
                        AppSelectOption(value: 1, label: '标准'),
                        AppSelectOption(value: 2, label: '稳妥'),
                      ],
                      onChanged: (value) => setState(() => selected = value),
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
    expect(find.text('下拉灵敏度'), findsOneWidget);
    expect(find.text('灵敏'), findsOneWidget);

    await tester.tap(find.text('下拉灵敏度'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('稳妥'));
    await tester.pumpAndSettle();

    expect(selected, 2);
    expect(find.text('下拉灵敏度'), findsOneWidget);
    expect(find.text('稳妥'), findsOneWidget);
  });
}
