import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/widget/business/account_lookup.dart';
import 'package:smartflow/widget/business/transaction_row.dart';

void main() {
  testWidgets('renders transaction row presentation', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountLookupProvider.overrideWith(
            (ref) => Stream.value(AccountLookup(_accounts)),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: TransactionRow(item: _item())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('08:30  午餐'), findsOneWidget);
    expect(find.text('-12.34'), findsOneWidget);
    expect(find.text('不计统计'), findsOneWidget);
  });
}

final _accounts = <String, Account>{
  'cash': _account('cash', '现金', iconKey: 'cash'),
  'food': _account('food', '餐饮', type: AccountType.expense, iconKey: 'meal'),
};

TransactionListItem _item() {
  return TransactionListItem(
    id: 'tx-1',
    rootTransactionId: 'tx-1',
    businessPurpose: BusinessPurpose.dailyExpense,
    businessState: BusinessState.current,
    occurredAt: DateTime(2026, 1, 1, 8, 30),
    primaryAmount: const Money(minorUnits: 1234),
    note: ' 午餐 ',
    isExcludedFromStats: true,
    isExcludedFromBudget: false,
    entries: const [
      Entry(
        id: 'entry-cash',
        transactionId: 'tx-1',
        accountId: 'cash',
        direction: EntryDirection.credit,
        amount: Money(minorUnits: 1234),
      ),
      Entry(
        id: 'entry-food',
        transactionId: 'tx-1',
        accountId: 'food',
        direction: EntryDirection.debit,
        amount: Money(minorUnits: 1234),
      ),
    ],
    details: const [],
  );
}

Account _account(
  String id,
  String name, {
  AccountType type = AccountType.asset,
  String? iconKey,
}) {
  return Account(
    id: id,
    name: name,
    type: type,
    iconKey: iconKey,
    balance: const Money(minorUnits: 0),
  );
}
