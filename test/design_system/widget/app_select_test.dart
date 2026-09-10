import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_select.dart';

void main() {
  for (final behavior in AppSelectMenuBehavior.values) {
    testWidgets(
      'nullable option is selectable and dismissal does not change it: $behavior',
      (tester) async {
        final changes = <int?>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AppSelectMenu<int?>(
                  value: 2026,
                  options: const [
                    AppSelectOption(value: null, label: '不限'),
                    AppSelectOption(value: 2026, label: '2026 年'),
                  ],
                  tooltip: '年份',
                  behavior: behavior,
                  onChanged: changes.add,
                  triggerBuilder: (context, option) => Text(option.label),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byTooltip('年份'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('不限'));
        await tester.pumpAndSettle();
        expect(changes, [null]);
        await tester.tap(find.byTooltip('年份'));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(changes, [null]);
      },
    );
  }

  testWidgets('select menu exposes the current value and updates it', (
    tester,
  ) async {
    var selected = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) {
                return AppSelectMenu<int>(
                  value: selected,
                  options: const [
                    AppSelectOption(value: 0, label: '灵敏'),
                    AppSelectOption(value: 1, label: '标准'),
                    AppSelectOption(value: 2, label: '稳妥'),
                  ],
                  tooltip: '选择灵敏度',
                  onChanged: (value) => setState(() => selected = value),
                  triggerBuilder: (context, option) => Text(option.label),
                );
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('标准'), findsOneWidget);

    await tester.tap(find.byTooltip('选择灵敏度'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('稳妥'));
    await tester.pumpAndSettle();

    expect(selected, 2);
    expect(find.text('稳妥'), findsOneWidget);
  });
}
