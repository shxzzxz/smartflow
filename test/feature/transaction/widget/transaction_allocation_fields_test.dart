import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/transaction/widget/transaction_allocation_fields.dart';

void main() {
  testWidgets('shows every name and edits allocation amounts in place', (
    tester,
  ) async {
    var allocations = [_allocation('food', 60)];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Form(
                child: TransactionAllocationAmountFields(
                  title: '退款分类',
                  allocations: allocations,
                  options: const [
                    TransactionAllocationOption(accountId: 'food', label: '餐饮'),
                    TransactionAllocationOption(
                      accountId: 'transport',
                      label: '交通',
                    ),
                  ],
                  expectedTotal: _money(100),
                  onChanged: (value) => setState(() => allocations = value),
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('交通'), findsOneWidget);
    expect(find.text('待分配 40'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('待分配 40')).dy,
      lessThan(
        tester
            .getTopLeft(
              find.descendant(
                of: find.byKey(const ValueKey('allocation-amount-food')),
                matching: find.byType(TextFormField),
              ),
            )
            .dy,
      ),
    );

    final transportAmount = find.descendant(
      of: find.byKey(const ValueKey('allocation-amount-transport')),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(transportAmount, '40');
    await tester.pump();

    expect(find.text('已匹配'), findsOneWidget);
    expect(
      allocations
          .map(
            (allocation) =>
                '${allocation.accountId}:${allocation.amount.minorUnits}',
          )
          .toList(),
      ['food:6000', 'transport:4000'],
    );
    expect(
      tester.widget<TextFormField>(transportAmount).controller?.text,
      '40',
    );
  });

  testWidgets('allows blank rows and validates a category maximum', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: TransactionAllocationAmountFields(
              title: '差额分类',
              allocations: const [],
              options: const [
                TransactionAllocationOption(accountId: 'food', label: '餐饮'),
                TransactionAllocationOption(
                  accountId: 'transport',
                  label: '交通',
                ),
              ],
              maximumByAccountId: {'food': _money(30)},
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(formKey.currentState!.validate(), isTrue);

    final foodAmount = find.descendant(
      of: find.byKey(const ValueKey('allocation-amount-food')),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(foodAmount, '31');
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();

    expect(find.text('不能超过可分配金额'), findsOneWidget);
  });
}

AccountAmountAllocation _allocation(String accountId, int amount) {
  return AccountAmountAllocation(accountId: accountId, amount: _money(amount));
}

Money _money(int amount) => Money(minorUnits: amount * 100);
