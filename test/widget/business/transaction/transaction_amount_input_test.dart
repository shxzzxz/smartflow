import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/widget/app_form_field.dart';
import 'package:smartflow/widget/business/finance/money_input.dart';
import 'package:smartflow/widget/business/finance/money_text.dart';
import 'package:smartflow/widget/business/transaction/transaction_amount_input.dart';

void main() {
  testWidgets('participates in validation and edits the note', (tester) async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    addTearDown(amountController.dispose);
    addTearDown(noteController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: TransactionAmountInput(
              amountController: amountController,
              noteController: noteController,
              semantic: MoneySemantic.expense,
              amountValidator: validatePositiveMoneyText,
            ),
          ),
        ),
      ),
    );

    expect(formKey.currentState!.validate(), false);
    await tester.pump();
    expect(find.text('请输入有效金额'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('transaction-note-input')),
        matching: find.byType(TextFormField),
      ),
      '午餐',
    );
    expect(noteController.text, '午餐');
  });

  testWidgets('fits all twelve amount digits without horizontal scrolling', (
    tester,
  ) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    addTearDown(amountController.dispose);
    addTearDown(noteController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 379,
              child: TransactionAmountInput(
                amountController: amountController,
                noteController: noteController,
                semantic: MoneySemantic.expense,
                amountValidator: (_) => null,
              ),
            ),
          ),
        ),
      ),
    );

    final amountFieldFinder = find.byKey(
      const ValueKey('transaction-amount-input'),
    );
    final editableFinder = find.descendant(
      of: amountFieldFinder,
      matching: find.byType(EditableText),
    );
    final initialWidth = tester.getSize(amountFieldFinder).width;
    final initialFontSize =
        tester.widget<EditableText>(editableFinder).style.fontSize;
    expect(
      find.byKey(const ValueKey('transaction-note-input')),
      findsOneWidget,
    );

    syncTextControllerText(amountController, '1234567890.12');
    await tester.pump();

    final editableState = tester.state<EditableTextState>(editableFinder);

    expect(tester.getSize(amountFieldFinder).width, greaterThan(initialWidth));
    expect(
      tester.widget<EditableText>(editableFinder).style.fontSize,
      initialFontSize,
    );
    expect(find.byKey(const ValueKey('transaction-note-input')), findsNothing);
    expect(editableState.renderEditable.maxScrollExtent, 0);
    expect(editableState.renderEditable.offset.pixels, 0);
  });
}
