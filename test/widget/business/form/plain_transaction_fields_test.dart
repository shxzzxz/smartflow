import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/widget/app_select.dart';
import 'package:smartflow/widget/business/finance/money_input.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';

void main() {
  group('money input helpers', () {
    test('appends keypad input with cent precision rules', () {
      expect(appendMoneyInputText('', '.'), '0.');
      expect(appendMoneyInputText('0', '5'), '5');
      expect(appendMoneyInputText('12.', '3'), '12.3');
      expect(appendMoneyInputText('12.3', '4'), '12.34');
      expect(appendMoneyInputText('12.34', '5'), '12.34');
      expect(appendMoneyInputText('12.34', '.'), '12.34');
      expect(appendMoneyInputText('12', 'x'), '12');
    });

    test('limits keypad input to twelve digits in total', () {
      expect(appendMoneyInputText('12345678901', '2'), '123456789012');
      expect(appendMoneyInputText('123456789012', '3'), '123456789012');
      expect(appendMoneyInputText('1234567890.1', '2'), '1234567890.12');
      expect(appendMoneyInputText('1234567890.12', '3'), '1234567890.12');
      expect(appendMoneyInputText('123456789012', '.'), '123456789012');
    });

    test('limits system keyboard input to twelve digits in total', () {
      const accepted = TextEditingValue(text: '1234567890.12');
      const overflow = TextEditingValue(text: '12345678901.12');

      expect(
        moneyInputFormatter.formatEditUpdate(
          const TextEditingValue(text: '1234567890.1'),
          accepted,
        ),
        accepted,
      );
      expect(
        moneyInputFormatter.formatEditUpdate(accepted, overflow),
        accepted,
      );
    });

    test('allows editing an existing negative amount', () {
      const oldValue = TextEditingValue(
        text: '-123.00',
        selection: TextSelection.collapsed(offset: 7),
      );
      const deletedLastDigit = TextEditingValue(
        text: '-123.0',
        selection: TextSelection.collapsed(offset: 6),
      );

      expect(
        moneyInputFormatter.formatEditUpdate(oldValue, deletedLastDigit),
        deletedLastDigit,
      );
    });

    test('deletes the last keypad character', () {
      expect(deleteLastMoneyInputText('12.3'), '12.');
      expect(deleteLastMoneyInputText(''), '');
    });

    test('validates positive and non-negative money text', () {
      expect(validatePositiveMoneyText('12.34'), isNull);
      expect(validatePositiveMoneyText('0'), '金额必须大于 0');
      expect(validatePositiveMoneyText(''), '请输入有效金额');
      expect(validatePositiveMoneyText('1.234'), '请输入有效金额');
      expect(validatePositiveMoneyText('1234567890123'), '请输入有效金额');

      expect(validateNonNegativeMoneyText('0'), isNull);
      expect(validateNonNegativeMoneyText('-0.01'), '金额不能小于 0');

      expect(validateOptionalNonNegativeMoneyText(''), isNull);
      expect(validateOptionalNonNegativeMoneyText('  '), isNull);
      expect(validateOptionalNonNegativeMoneyText('8.00'), isNull);
      expect(validateOptionalNonNegativeMoneyText('-0.01'), '金额不能小于 0');
    });

    test('parses minor units when valid', () {
      expect(parseMoneyMinorUnitsOrNull('12.34'), 1234);
      expect(parseMoneyMinorUnitsOrNull('bad'), isNull);
    });
  });

  group('account helpers', () {
    test('resolves selected and fallback accounts', () {
      final accounts = [_account('cash'), _account('bank')];

      expect(containsAccount(accounts, 'cash'), true);
      expect(containsAccount(accounts, 'missing'), false);
      expect(findAccountById('bank', accounts)?.id, 'bank');
      expect(findAccountById('missing', accounts), isNull);
      expect(effectiveAccountId('bank', accounts), 'bank');
      expect(effectiveAccountId('missing', accounts), 'cash');
      expect(effectiveAccount('missing', accounts)?.id, 'cash');
      expect(effectiveAccountId(null, const []), isNull);
    });
  });

  testWidgets('account row keeps selection and Form state in sync', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    final accounts = [_account('cash'), _account('bank')];
    late StateSetter rebuild;
    String? selectedId = 'cash';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Form(
                key: formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: AccountPlainFormRow(
                  label: '账户',
                  account: findAccountById(selectedId, accounts),
                  selectedId: selectedId,
                  placeholder: '请选择账户',
                  onTap: (onSelected) => onSelected('bank'),
                  onChanged: (value) => rebuild(() => selectedId = value),
                  validator: (value) => value == 'bank' ? null : '请选择银行卡',
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(formKey.currentState!.validate(), false);
    await tester.pump();
    expect(find.text('请选择银行卡'), findsOneWidget);

    await tester.tap(find.text('cash'));
    await tester.pump();

    expect(selectedId, 'bank');
    expect(find.text('请选择银行卡'), findsNothing);
    expect(formKey.currentState!.validate(), true);

    formKey.currentState!.reset();
    await tester.pump();

    expect(selectedId, 'cash');
    expect(find.text('cash'), findsOneWidget);
  });

  testWidgets('dropdown row restores its controlled value on Form reset', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    var selected = _TestChoice.first;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Form(
                key: formKey,
                child: DropdownPlainFormRow<_TestChoice>(
                  label: '选项',
                  value: selected,
                  items: const [
                    DropdownMenuItem(
                      value: _TestChoice.first,
                      child: Text('第一项'),
                    ),
                    DropdownMenuItem(
                      value: _TestChoice.second,
                      child: Text('第二项'),
                    ),
                  ],
                  onChanged: (value) => setState(() => selected = value),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('第一项'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第二项').last);
    await tester.pumpAndSettle();

    expect(selected, _TestChoice.second);

    formKey.currentState!.reset();
    await tester.pump();

    expect(selected, _TestChoice.first);
    expect(find.text('第一项'), findsOneWidget);
  });

  testWidgets('date row restores its nullable value on Form reset', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    DateTime? date;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Form(
                key: formKey,
                child: DateTimePlainFormRow(
                  label: '日期',
                  dateTime: date,
                  value: date == null ? '自动计算' : _dateText(date!),
                  onTap: (onSelected) => onSelected(DateTime(2026, 2, 2)),
                  onChanged: (value) => setState(() => date = value),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('自动计算'));
    await tester.pump();
    expect(date, DateTime(2026, 2, 2));

    formKey.currentState!.reset();
    await tester.pump();

    expect(date, isNull);
    expect(find.text('自动计算'), findsOneWidget);
  });

  testWidgets('date row hides its chevron by default', (tester) async {
    final date = DateTime(2026, 2, 2, 9, 30);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DateTimePlainFormRow(
            label: '日期',
            dateTime: date,
            value: _dateText(date),
            onTap: (_) {},
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
  });

  testWidgets('billing and repayment fields always stack', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 480,
            child: BillingRepaymentDayPlainFields(
              billingDay: null,
              repaymentDay: null,
              onSelectBillingDay: _noop,
              onSelectRepaymentDay: _noop,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.text('还款日')).dy,
      greaterThan(tester.getTopLeft(find.text('出账日')).dy),
    );
  });

  testWidgets('billing and repayment fields stack for large text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
        child: const MaterialApp(
          home: Scaffold(
            body: BillingRepaymentDayPlainFields(
              billingDay: null,
              repaymentDay: null,
              onSelectBillingDay: _noop,
              onSelectRepaymentDay: _noop,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.text('还款日')).dy,
      greaterThan(tester.getTopLeft(find.text('出账日')).dy),
    );
  });

  testWidgets('value-with-unit row restores its unit on Form reset', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: '7.2');
    addTearDown(controller.dispose);
    var unit = _TestChoice.first;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Form(
                key: formKey,
                child: ValueWithUnitPlainFormRow<_TestChoice>(
                  label: '利率',
                  controller: controller,
                  unit: unit,
                  suffixText: '%',
                  unitOptions: const [
                    AppSelectOption(value: _TestChoice.first, label: '月'),
                    AppSelectOption(value: _TestChoice.second, label: '年'),
                  ],
                  onUnitChanged: (next) => setState(() => unit = next),
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('%'), findsOneWidget);
    expect(find.byType(DropdownButton<_TestChoice>), findsNothing);
    expect(find.byType(AppSelectMenu<_TestChoice>), findsOneWidget);

    await tester.tap(find.text('月'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('年').last);
    await tester.pumpAndSettle();
    expect(unit, _TestChoice.second);

    formKey.currentState!.reset();
    await tester.pump();

    expect(unit, _TestChoice.first);
    expect(find.text('月'), findsOneWidget);
  });
}

void _noop() {}

enum _TestChoice { first, second }

String _dateText(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

Account _account(String id) {
  return Account(
    id: id,
    name: id,
    type: AccountType.asset,
    balance: const Money(minorUnits: 0),
  );
}
