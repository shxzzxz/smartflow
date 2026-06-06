import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/widget/business/account_lookup.dart';
import 'package:smartflow/widget/business/transaction_list_presentation.dart';
import 'package:smartflow/widget/business/transaction_row.dart';

void main() {
  testWidgets('renders controlled transaction row presentation', (
    tester,
  ) async {
    var tapped = false;
    final presentation = buildTransactionRowPresentation(
      item: _item(),
      accountLookup: AccountLookup(_accounts),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TransactionRow(
            presentation: presentation,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('08:30  午餐'), findsOneWidget);
    expect(find.text('-12.34'), findsOneWidget);
    expect(find.text('不计统计'), findsOneWidget);

    await tester.tap(find.text('餐饮'));
    expect(tapped, true);
  });

  testWidgets('calls quick edit callback from swipe action', (tester) async {
    var quickEdited = false;
    final presentation = buildTransactionRowPresentation(
      item: _item(),
      accountLookup: AccountLookup(_accounts),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: TransactionRow(
              presentation: presentation,
              onTap: () {},
              onQuickEdit: () => quickEdited = true,
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(TransactionRow), const Offset(180, 0));
    await tester.pumpAndSettle();

    expect(quickEdited, true);
  });
}

final _accounts = <String, Account>{
  'cash': _account('cash', '现金', iconKey: 'cash'),
  'food': _account('food', '餐饮', type: AccountType.expense, iconKey: 'meal'),
};

TransactionListReadModel _item() {
  return TransactionListReadModel(
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
