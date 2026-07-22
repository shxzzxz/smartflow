import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import 'package:smartflow/widget/business/category/category_avatar.dart';
import 'package:smartflow/widget/business/finance/adaptive_money_text.dart';
import 'package:smartflow/widget/business/finance/finance_tone.dart';
import 'package:smartflow/widget/business/transaction/transaction_row.dart';
import 'package:smartflow/widget/business/transaction/transaction_progress_badges.dart';

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
    expect(tester.widget<Text>(find.text('餐饮')).style?.fontSize, 15);
    expect(tester.widget<Text>(find.text('-12.34')).style?.fontSize, 15);
    expect(tester.widget<Text>(find.text('08:30')).style?.fontSize, 12);
    expect(tester.widget<Text>(find.text('不计统计')).style?.fontSize, 12);
    expect(tester.getTopRight(find.text('-12.34')).dx, closeTo(792, 0.1));
    expect(tester.getTopRight(find.text('现金')).dx, closeTo(792, 0.1));

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

  testWidgets(
    'shows a single badge at its natural width when space is available',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 500,
              child: TransactionRow(
                presentation: _presentationWithBadgeLabels(['不计预算']),
                onTap: () {},
                enableQuickEdit: false,
              ),
            ),
          ),
        ),
      );

      final finder = find.text('不计预算');
      final text = tester.widget<Text>(finder);
      final painter = TextPainter(
        text: TextSpan(text: '不计预算', style: text.style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();

      expect(tester.getSize(finder).width, greaterThanOrEqualTo(painter.width));
    },
  );

  testWidgets('uses the first measured badge combination that fits', (
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
    expect(find.text('B2'), findsNothing);
    expect(find.text('B3'), findsNothing);
    expect(find.text('+4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps an aggregate badge when four badges do not all fit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            width: 90,
            child: TransactionProgressBadges(
              badges: [
                TransactionBadgePresentation(
                  label: 'B1',
                  tone: FinanceTone.info,
                ),
                TransactionBadgePresentation(
                  label: 'B2',
                  tone: FinanceTone.info,
                ),
                TransactionBadgePresentation(
                  label: 'B3',
                  tone: FinanceTone.info,
                ),
                TransactionBadgePresentation(
                  label: 'B4',
                  tone: FinanceTone.info,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('B1'), findsOneWidget);
    expect(find.text('B2'), findsOneWidget);
    expect(find.text('B3'), findsNothing);
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets(
    'keeps a partial aggregate candidate when full labels do not fit',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: SizedBox(
              width: 140,
              child: TransactionProgressBadges(
                badges: [
                  TransactionBadgePresentation(
                    label: '退 2',
                    tone: FinanceTone.income,
                  ),
                  TransactionBadgePresentation(
                    label: '不计统计',
                    tone: FinanceTone.equity,
                  ),
                  TransactionBadgePresentation(
                    label: '不计预算',
                    tone: FinanceTone.equity,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('退 2'), findsOneWidget);
      expect(find.text('不计统计'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('不计预算'), findsNothing);
    },
  );

  testWidgets('does not leave title flex space unused before the amount', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 345,
            child: TransactionRow(
              presentation: _presentationWithBadgeLabels(
                const ['退 2', '不计统计', '不计预算'],
                title: '人情社交',
                amountText: '-37',
                originalAmountText: '-39',
                originalCompactAmountText: '-39',
              ),
              onTap: () {},
              enableQuickEdit: false,
            ),
          ),
        ),
      ),
    );

    final badgesRect = tester.getRect(find.byType(TransactionProgressBadges));
    final amountColumnRect = tester.getRect(find.byType(ComparedMoneyText));

    expect(find.text('退 2'), findsOneWidget);
    expect(find.text('不计统计'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('不计预算'), findsNothing);
    expect(
      amountColumnRect.left - badgesRect.right,
      closeTo(AppSpacing.space8, 0.1),
    );
  });

  testWidgets('prefers the precise amount while it fits the amount column', (
    tester,
  ) async {
    final presentation = _presentationWithBadges(
      0,
      amountText: '52000',
      compactAmountText: '5.2万',
    );

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

    expect(find.text('52000'), findsOneWidget);
    expect(find.text('5.2万'), findsNothing);
  });

  testWidgets(
    'uses the compact amount only when the precise amount does not fit',
    (tester) async {
      final presentation = _presentationWithBadges(
        0,
        amountText: '-123456789.12',
        compactAmountText: '-1.23亿',
      );

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

      expect(find.text('-123456789.12'), findsNothing);
      expect(find.text('-1.23亿'), findsOneWidget);
    },
  );

  testWidgets('shows original and actual amounts for adjusted transactions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TransactionRow(
            presentation: _presentationWithBadges(
              0,
              amountText: '-80',
              compactAmountText: '-80',
              originalAmountText: '-100',
              originalCompactAmountText: '-100',
            ),
            onTap: () {},
            enableQuickEdit: false,
          ),
        ),
      ),
    );

    expect(find.text('-80'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('-100')).style?.decoration,
      TextDecoration.lineThrough,
    );
    expect(tester.getTopRight(find.text('-80')).dx, closeTo(792, 0.1));
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

TransactionRowPresentation _presentationWithBadges(
  int count, {
  String amountText = '-1.24万',
  String? compactAmountText,
  String? originalAmountText,
  String? originalCompactAmountText,
}) {
  return TransactionRowPresentation(
    transactionId: 'badge-row',
    iconKey: 'meal',
    title: '超长分类名称',
    subtitle: '08:30',
    amountText: amountText,
    compactAmountText: compactAmountText,
    originalAmountText: originalAmountText,
    originalCompactAmountText: originalCompactAmountText,
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

TransactionRowPresentation _presentationWithBadgeLabels(
  List<String> labels, {
  String title = '超长分类名称',
  String? amountText,
  String? originalAmountText,
  String? originalCompactAmountText,
}) {
  final presentation = _presentationWithBadges(
    0,
    amountText: amountText ?? '-1.24万',
    originalAmountText: originalAmountText,
    originalCompactAmountText: originalCompactAmountText,
  );
  return TransactionRowPresentation(
    transactionId: presentation.transactionId,
    iconKey: presentation.iconKey,
    title: title,
    subtitle: presentation.subtitle,
    amountText: presentation.amountText,
    compactAmountText: presentation.compactAmountText,
    originalAmountText: presentation.originalAmountText,
    originalCompactAmountText: presentation.originalCompactAmountText,
    amountTone: presentation.amountTone,
    accountFlow: presentation.accountFlow,
    badges: [
      for (final label in labels)
        TransactionBadgePresentation(label: label, tone: FinanceTone.info),
    ],
    canQuickEdit: presentation.canQuickEdit,
  );
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
