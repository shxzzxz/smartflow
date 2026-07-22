import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
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
                child: AccountPlainFormRow(
                  label: '账户',
                  account: findAccountById(selectedId, accounts),
                  selectedId: selectedId,
                  placeholder: '请选择账户',
                  onTap: () => rebuild(() => selectedId = 'bank'),
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

    await tester.tap(find.text('cash'));
    await tester.pump();

    expect(selectedId, 'bank');
    expect(formKey.currentState!.validate(), true);

    formKey.currentState!.reset();
    await tester.pump();

    expect(selectedId, 'cash');
    expect(find.text('cash'), findsOneWidget);
  });
}

Account _account(String id) {
  return Account(
    id: id,
    name: id,
    type: AccountType.asset,
    balance: const Money(minorUnits: 0),
  );
}
