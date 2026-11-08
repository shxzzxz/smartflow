import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/widget/business/finance/money_input.dart';

void main() {
  testWidgets('keeps the amount value vertically centered with its label', (
    tester,
  ) async {
    final controller = TextEditingController(text: '7000');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MoneyPlainFormRow(label: '本金', controller: controller),
        ),
      ),
    );

    await tester.tap(find.byType(EditableText));
    await tester.pump();

    expect(find.byTooltip('清空本金'), findsOneWidget);
    final labelCenter = tester.getCenter(find.text('本金'));
    final valueCenter = tester.getCenter(find.text('7000'));

    expect((labelCenter.dy - valueCenter.dy).abs(), lessThan(1));
  });

  testWidgets('shows the clear action only for the focused money row', (
    tester,
  ) async {
    final principalController = TextEditingController(text: '7000');
    final interestController = TextEditingController(text: '20.1');
    addTearDown(principalController.dispose);
    addTearDown(interestController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              MoneyPlainFormRow(
                key: const ValueKey('principal'),
                label: '本金',
                controller: principalController,
              ),
              MoneyPlainFormRow(
                key: const ValueKey('interest'),
                label: '利息',
                controller: interestController,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byTooltip('清空本金'), findsNothing);
    expect(find.byTooltip('清空利息'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('principal')),
        matching: find.byType(EditableText),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('清空本金'), findsOneWidget);
    expect(find.byTooltip('清空利息'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('interest')),
        matching: find.byType(EditableText),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('清空本金'), findsNothing);
    expect(find.byTooltip('清空利息'), findsOneWidget);
  });

  testWidgets('clears a prefilled money input from the trailing action', (
    tester,
  ) async {
    final controller = TextEditingController(text: '200.1');
    addTearDown(controller.dispose);
    String? changedText;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MoneyPlainFormRow(
            label: '实收金额',
            controller: controller,
            onChanged: (value) => changedText = value,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(EditableText));
    await tester.pump();

    expect(find.text('200.1'), findsOneWidget);
    expect(find.byTooltip('清空实收金额'), findsOneWidget);

    await tester.tap(find.byTooltip('清空实收金额'));
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(changedText, isEmpty);
    expect(find.byTooltip('清空实收金额'), findsNothing);
  });
}
