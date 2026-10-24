import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
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
  for (final purpose in [
    BusinessPurpose.dailyExpense,
    BusinessPurpose.dailyIncome,
    BusinessPurpose.advance,
  ]) {
    testWidgets('renders multiple categories for ${purpose.name}', (
      tester,
    ) async {
      final row = buildTransactionRowPresentation(
        item: _item(purpose: purpose, multipleCategories: true),
        accountLookup: _lookup,
      ).copyWith(dimmed: true);
      expect(row.hasMultipleCategories, isTrue);
      expect(row.iconKey, isNull);
      expect(row.title, '多类别');
      expect(row.amountText, switch (purpose) {
        BusinessPurpose.dailyIncome => '+12.34',
        BusinessPurpose.dailyExpense => '-12.34',
        _ => '12.34',
      });
      expect(row.accountFlow.singleEndpoint.label, '现金');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: TransactionRow(presentation: row)),
        ),
      );
      expect(find.text('多类别'), findsOneWidget);
      expect(find.byIcon(RemixIcons.layout_grid_line), findsOneWidget);
      expect(find.byType(CategoryAvatar), findsNothing);
      expect(find.text(row.amountText), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TransactionRow(presentation: row.copyWith(selectable: true)),
          ),
        ),
      );
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.byIcon(RemixIcons.layout_grid_line), findsNothing);
    });
  }

  for (final scenario in [
    (BusinessPurpose.transfer, RemixIcons.arrow_left_right_line, '现金', '银行卡'),
    (BusinessPurpose.lending, RemixIcons.logout_box_r_line, '现金', '应收款'),
    (BusinessPurpose.debtRepayment, RemixIcons.refund_2_line, '现金', '借款'),
    (BusinessPurpose.borrowing, RemixIcons.hand_coin_line, '借款', '现金'),
    (
      BusinessPurpose.receivableCollection,
      RemixIcons.login_box_line,
      '应收款',
      '现金',
    ),
  ]) {
    testWidgets(
      'renders purpose icon and account direction for ${scenario.$1}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark(),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  child: TransactionRow(
                    presentation: TransactionRowPresentation(
                      transactionId: 'flow',
                      businessPurpose: scenario.$1,
                      iconKey: null,
                      title: '交易',
                      subtitle: '08:30',
                      amountText: '100',
                      amountTone: FinanceTone.neutral,
                      accountFlow: TransactionAccountFlowPresentation(
                        out: AccountEndpointPresentation(label: scenario.$3),
                        in_: AccountEndpointPresentation(label: scenario.$4),
                      ),
                      badges: const [],
                      canQuickEdit: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.byIcon(scenario.$2), findsOneWidget);
        expect(find.byType(CategoryAvatar), findsNothing);
        expect(find.text(scenario.$3), findsOneWidget);
        expect(find.text(scenario.$4), findsOneWidget);
        expect(find.text('->'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text(scenario.$3)).dx,
          lessThan(tester.getTopLeft(find.text('->')).dx),
        );
        expect(
          tester.getTopLeft(find.text('->')).dx,
          lessThan(tester.getTopLeft(find.text(scenario.$4)).dx),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('renders controlled transaction row presentation', (
    tester,
  ) async {
    var tapped = false;
    final presentation = buildTransactionRowPresentation(
      item: _item(),
      accountLookup: _lookup,
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

  testWidgets('replaces the category icon with the selection checkbox', (
    tester,
  ) async {
    final presentation = buildTransactionRowPresentation(
      item: _item(),
      accountLookup: _lookup,
    ).copyWith(selectable: true);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TransactionRow(
            presentation: presentation,
            onTap: () {},
            onSelectionChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.byType(CategoryAvatar), findsNothing);
  });

  testWidgets('批量提交中复选框渲染为禁用态', (tester) async {
    final presentation = buildTransactionRowPresentation(
      item: _item(),
      accountLookup: _lookup,
    ).copyWith(selectable: true);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TransactionRow(presentation: presentation, onTap: () {}),
        ),
      ),
    );

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
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
      accountLookup: _lookup,
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

TransactionReadModel _item({
  BusinessPurpose purpose = BusinessPurpose.dailyExpense,
  bool multipleCategories = false,
}) {
  return TransactionReadModel(
    id: 'tx-1',
    businessPurpose: purpose,
    occurredAt: DateTime(2026, 1, 1, 8, 30),
    primaryAmount: const Money(minorUnits: 1234),
    isExcludedFromStats: true,
    isExcludedFromBudget: false,
    lines: [
      TransactionLine(
        id: 'category',
        transactionId: 'tx-1',
        lineNo: 1,
        role: purpose == BusinessPurpose.advance
            ? TransactionRole.advanceExpenseCategory
            : TransactionRole.category,
        accountId: 'food',
        amount: Money(minorUnits: multipleCategories ? 600 : 1234),
      ),
      if (multipleCategories)
        TransactionLine(
          id: 'second-category',
          transactionId: 'tx-1',
          lineNo: 3,
          role: purpose == BusinessPurpose.advance
              ? TransactionRole.advanceExpenseCategory
              : TransactionRole.category,
          accountId: 'other-category',
          amount: const Money(minorUnits: 634),
        ),
      TransactionLine(
        id: 'settlement',
        transactionId: 'tx-1',
        lineNo: 2,
        role: purpose == BusinessPurpose.dailyIncome
            ? TransactionRole.settlementIn
            : TransactionRole.settlementOut,
        accountId: 'cash',
        amount: const Money(minorUnits: 1234),
      ),
    ],
    impactsByAccountId: const {
      'food': TransactionAccountImpact(
        debitAmount: Money(minorUnits: 1234),
        creditAmount: Money(minorUnits: 0),
        netChange: Money(minorUnits: 1234),
      ),
      'cash': TransactionAccountImpact(
        debitAmount: Money(minorUnits: 0),
        creditAmount: Money(minorUnits: 1234),
        netChange: Money(minorUnits: -1234),
      ),
    },
  );
}

final _lookup = AccountLookup({
  'food': Account(
    id: 'food',
    name: '餐饮',
    type: AccountType.expense,
    iconKey: 'meal',
    balance: Money.zero(),
  ),
  'cash': Account(
    id: 'cash',
    name: '现金',
    type: AccountType.asset,
    iconKey: 'cash',
    balance: Money.zero(),
  ),
});
