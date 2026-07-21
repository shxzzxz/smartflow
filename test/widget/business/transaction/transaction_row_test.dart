import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import 'package:smartflow/widget/business/category/category_avatar.dart';
import 'package:smartflow/widget/business/finance/finance_tone.dart';
import 'package:smartflow/widget/business/transaction/transaction_row.dart';

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
    expect(find.text('08:30'), findsOneWidget);
    expect(find.text('午餐'), findsNothing);
    expect(find.text('现金'), findsOneWidget);
    expect(find.text('-12.34'), findsOneWidget);
    expect(find.text('不计统计'), findsOneWidget);

    expect(tester.getSize(find.byType(TransactionRow)).height, 58);
    expect(tester.getSize(find.byType(CategoryAvatar)), const Size(32, 32));
    expect(tester.getTopLeft(find.byType(CategoryAvatar)).dx, 8);
    expect(tester.widget<Text>(find.text('餐饮')).style?.fontSize, 18);
    expect(tester.widget<Text>(find.text('-12.34')).style?.fontSize, 18);
    expect(tester.widget<Text>(find.text('08:30')).style?.fontSize, 12);
    expect(tester.widget<Text>(find.text('不计统计')).style?.fontSize, 12);

    await tester.tap(find.text('餐饮'));
    expect(tapped, true);
  });

  testWidgets(
    'aggregates badges into four slots without horizontal scrolling',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 500,
              child: TransactionRow(
                presentation: _presentationWithBadges(5),
                onTap: () {},
                enableQuickEdit: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('B1'), findsOneWidget);
      expect(find.text('B2'), findsOneWidget);
      expect(find.text('B3'), findsOneWidget);
      expect(find.text('B4'), findsNothing);
      expect(find.text('+2'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TransactionRow),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('falls back to three badge slots in constrained width', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: TransactionRow(
              presentation: _presentationWithBadges(5),
              onTap: () {},
              enableQuickEdit: false,
            ),
          ),
        ),
      ),
    );

    expect(find.text('B1'), findsOneWidget);
    expect(find.text('B2'), findsOneWidget);
    expect(find.text('B3'), findsNothing);
    expect(find.text('+3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not shrink an oversized amount below fourteen pixels', (
    tester,
  ) async {
    final presentation = _presentationWithBadges(
      0,
    ).copyWithAmount('-12345678901234567890W');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: TransactionRow(
              presentation: presentation,
              onTap: () {},
              enableQuickEdit: false,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('-12345678901234567890W')).style?.fontSize,
      14,
    );
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

TransactionRowPresentation _presentationWithBadges(int count) {
  return TransactionRowPresentation(
    transactionId: 'badge-row',
    iconKey: 'meal',
    title: '超长分类名称',
    subtitle: '08:30',
    amountText: '-1.24W',
    amountTone: FinanceTone.expense,
    accountFlow: const TransactionAccountFlowPresentation(
      out: AccountEndpointPresentation(
        label: '招商银行储蓄卡长名称',
        iconKey: 'cmb_credit_card',
      ),
    ),
    badges: [
      for (var index = 1; index <= count; index++)
        TransactionBadgePresentation(label: 'B$index', tone: FinanceTone.info),
    ],
    canQuickEdit: false,
  );
}

extension on TransactionRowPresentation {
  TransactionRowPresentation copyWithAmount(String amountText) {
    return TransactionRowPresentation(
      transactionId: transactionId,
      iconKey: iconKey,
      title: title,
      subtitle: subtitle,
      amountText: amountText,
      amountTone: this.amountTone,
      accountFlow: accountFlow,
      badges: badges,
      canQuickEdit: canQuickEdit,
    );
  }
}

final _accounts = <String, Account>{
  'cash': _account('cash', '现金', iconKey: 'cash'),
  'food': _account('food', '餐饮', type: AccountType.expense, iconKey: 'meal'),
};

TransactionListReadModel _item() {
  return TransactionListReadModel(
    id: 'tx-1',
    businessPurpose: BusinessPurpose.dailyExpense,
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
