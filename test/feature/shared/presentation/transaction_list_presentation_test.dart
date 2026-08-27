import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/budget/presentation/budget_transaction_presentation.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import 'package:smartflow/widget/business/finance/finance_tone.dart';

void main() {
  group('transaction list presentation', () {
    test('builds budget transaction rows from category impact amounts', () {
      final groups = budgetTransactionGroups(
        transactions: [_item()],
        accountLookup: _lookup,
        categoryId: 'food',
      );

      expect(groups, hasLength(1));
      expect(groups.single.rows.single.transactionId, 'tx-1');
      expect(groups.single.rows.single.amountText, '-12.34');
    });

    test('groups transactions with daily summaries by descending date', () {
      final jan1 = DateTime(2026, 1, 1, 8);
      final jan2 = DateTime(2026, 1, 2, 9);

      final groups = groupTransactionsByDay(
        accountLookup: _lookup,
        items: [
          _item(id: 'a', occurredAt: jan1),
          _item(id: 'b', occurredAt: jan2),
        ],
        dailySummaries: [
          DailyCashflowSummary(
            date: DateTime(2026, 1, 1),
            income: const Money(minorUnits: 300),
            expense: const Money(minorUnits: 100),
          ),
        ],
      );

      expect(groups.map((group) => group.date), [
        DateTime(2026, 1, 2),
        DateTime(2026, 1, 1),
      ]);
      expect(groups.first.rows.single.transactionId, 'b');
      expect(groups.last.incomeMinor, 300);
      expect(groups.last.expenseMinor, 100);
    });

    test('does not create transaction groups from daily summaries alone', () {
      final groups = groupTransactionsByDay(
        accountLookup: _lookup,
        items: const [],
        dailySummaries: [
          DailyCashflowSummary(
            date: DateTime(2026, 1, 1),
            income: const Money(minorUnits: 0),
            expense: const Money(minorUnits: 0),
          ),
          DailyCashflowSummary(
            date: DateTime(2026, 1, 2),
            income: const Money(minorUnits: 300),
            expense: const Money(minorUnits: 100),
          ),
        ],
      );

      expect(groups, isEmpty);
    });

    test('groups controlled row presentations by descending date', () {
      final jan1 = DateTime(2026, 1, 1, 8);
      final jan2 = DateTime(2026, 1, 2, 9);

      final groups = groupTransactionsByDay(
        accountLookup: _lookup,
        items: [
          _item(id: 'a', occurredAt: jan1),
          _item(id: 'b', occurredAt: jan2),
        ],
        dailySummaries: [
          DailyCashflowSummary(
            date: DateTime(2026, 1, 1),
            income: const Money(minorUnits: 300),
            expense: const Money(minorUnits: 100),
          ),
        ],
      );

      expect(groups.map((group) => group.date), [
        DateTime(2026, 1, 2),
        DateTime(2026, 1, 1),
      ]);
      expect(groups.first.rows.single.transactionId, 'b');
      expect(groups.last.rows.single.title, '餐饮');
      expect(groups.last.incomeMinor, 300);
    });

    test('builds row text, tone, account flow, and badges', () {
      final item = _item(
        isExcludedFromStats: true,
        refundedTotal: const Money(minorUnits: 230),
      );

      final row = buildTransactionRowPresentation(
        item: item,
        accountLookup: _lookup,
      );

      expect(row.title, '餐饮');
      expect(row.transactionId, 'tx-1');
      expect(row.subtitle, '08:30');
      expect(row.amountText, '-10.04');
      expect(row.originalAmountText, '-12.34');
      expect(row.amountTone, FinanceTone.expense);
      expect(row.iconKey, 'meal');
      expect(row.accountFlow.out?.label, '现金');
      expect(row.badges.map((badge) => badge.label), ['退 2.3', '不计统计']);
      expect(row.canQuickEdit, true);
    });

    test('keeps every combined payment account for icon-only rendering', () {
      final item = TransactionReadModel(
        id: 'combined-payment',
        businessPurpose: BusinessPurpose.dailyExpense,
        occurredAt: DateTime(2026, 1, 1, 8, 30),
        primaryAmount: const Money(minorUnits: 10000),
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
        lines: const [
          TransactionLine(
            id: 'category',
            transactionId: 'combined-payment',
            lineNo: 1,
            role: TransactionRole.category,
            accountId: 'food',
            amount: Money(minorUnits: 10000),
          ),
          TransactionLine(
            id: 'cash',
            transactionId: 'combined-payment',
            lineNo: 2,
            role: TransactionRole.settlementOut,
            accountId: 'cash',
            amount: Money(minorUnits: 6000),
          ),
          TransactionLine(
            id: 'card',
            transactionId: 'combined-payment',
            lineNo: 3,
            role: TransactionRole.settlementOut,
            accountId: 'card',
            amount: Money(minorUnits: 4000),
          ),
        ],
      );

      final row = buildTransactionRowPresentation(
        item: item,
        accountLookup: _lookup,
      );

      expect(row.accountFlow.outEndpoints.map((endpoint) => endpoint.label), [
        '现金',
        '银行卡',
      ]);
    });

    test('uses expense and income signs for bad debt and debt relief', () {
      final badDebt = buildTransactionRowPresentation(
        item: _item(businessPurpose: BusinessPurpose.badDebt),
        accountLookup: _lookup,
      );
      final debtRelief = buildTransactionRowPresentation(
        item: _item(businessPurpose: BusinessPurpose.debtRelief),
        accountLookup: _lookup,
      );

      expect(badDebt.amountText, '-12.34');
      expect(badDebt.amountTone, FinanceTone.expense);
      expect(debtRelief.amountText, '+12.34');
      expect(debtRelief.amountTone, FinanceTone.income);
    });

    test('shows a transfer fee badge', () {
      final row = buildTransactionRowPresentation(
        item: _item(
          businessPurpose: BusinessPurpose.transfer,
          adjustments: const [
            TransactionAdjustment(
              kind: TransactionAdjustmentKind.transferFee,
              amount: Money(minorUnits: 300),
            ),
          ],
        ),
        accountLookup: _lookup,
      );

      expect(row.badges.map((badge) => badge.label), ['费 3']);
    });

    test(
      'shows refund and reimbursement badges while refund adjusts advance amount',
      () {
        final row = buildTransactionRowPresentation(
          accountLookup: _lookup,
          item: _item(
            businessPurpose: BusinessPurpose.reimbursementAdvance,
            primaryAmount: const Money(minorUnits: 10000),
            refundedTotal: const Money(minorUnits: 2000),
            reimbursementReceivedTotal: const Money(minorUnits: 4000),
          ),
        );

        expect(row.badges.map((badge) => badge.label), ['退 20', '报 40']);
        expect(row.originalAmountText, '100');
        expect(row.amountText, '80');
        expect(row.amountTone, FinanceTone.neutral);
      },
    );

    test('hides collection principal badge and keeps interest badge', () {
      final row = buildTransactionRowPresentation(
        accountLookup: _lookup,
        item: _item(
          businessPurpose: BusinessPurpose.receivableCollection,
          adjustments: const [
            TransactionAdjustment(
              kind: TransactionAdjustmentKind.receivableCollectionPrincipal,
              amount: Money(minorUnits: 10000),
            ),
            TransactionAdjustment(
              kind: TransactionAdjustmentKind.receivableCollectionInterest,
              amount: Money(minorUnits: 500),
            ),
          ],
        ),
      );

      expect(row.badges.map((badge) => badge.label), ['利息 5']);
    });

    test('uses account balance delta in account ledger mode', () {
      final row = buildTransactionRowPresentation(
        item: _item(),
        accountLookup: _lookup,
        amountSource: const TransactionAccountImpactAmountSource('cash'),
      );

      expect(row.amountText, '-12.34');
      expect(row.amountTone, FinanceTone.neutral);
    });

    test(
      'uses no account label when the settlement account is unavailable',
      () {
        final row = buildTransactionRowPresentation(
          item: _item(impactsByAccountId: const {}),
          accountLookup: _lookup,
        );

        expect(row.accountFlow.singleEndpoint.label, '无账户');
      },
    );

    test('keeps adjustments orthogonal to account and category amounts', () {
      final parent = _item(
        id: 'parent',
        primaryAmount: const Money(minorUnits: 2000),
        refundedTotal: const Money(minorUnits: 200),
        impactsByAccountId: const {
          'food': TransactionAccountImpact(
            debitAmount: Money(minorUnits: 2000),
            creditAmount: Money(minorUnits: 0),
            netChange: Money(minorUnits: 2000),
          ),
          'cash': TransactionAccountImpact(
            debitAmount: Money(minorUnits: 0),
            creditAmount: Money(minorUnits: 2000),
            netChange: Money(minorUnits: -2000),
          ),
        },
      );
      final refund = _item(
        id: 'refund',
        businessPurpose: BusinessPurpose.refund,
        primaryAmount: const Money(minorUnits: 200),
        impactsByAccountId: const {
          'food': TransactionAccountImpact(
            debitAmount: Money(minorUnits: 0),
            creditAmount: Money(minorUnits: 200),
            netChange: Money(minorUnits: -200),
          ),
          'cash': TransactionAccountImpact(
            debitAmount: Money(minorUnits: 200),
            creditAmount: Money(minorUnits: 0),
            netChange: Money(minorUnits: 200),
          ),
        },
      );

      final groupRow = buildTransactionRowPresentation(
        item: parent,
        accountLookup: _lookup,
      );
      final accountRows = [parent, refund]
          .map(
            (item) => buildTransactionRowPresentation(
              item: item,
              accountLookup: _lookup,
              amountSource: const TransactionAccountImpactAmountSource('cash'),
            ),
          )
          .toList();
      final categoryRows = [parent, refund]
          .map(
            (item) => buildTransactionRowPresentation(
              item: item,
              accountLookup: _lookup,
              amountSource: const TransactionCategoryImpactAmountSource({
                'food',
              }),
            ),
          )
          .toList();

      expect(groupRow.amountText, '-18');
      expect(groupRow.originalAmountText, '-20');
      expect(accountRows.map((row) => row.amountText), ['-20', '+2']);
      expect(categoryRows.map((row) => row.amountText), ['-20', '+2']);
      expect(categoryRows.first.originalAmountText, isNull);
    });

    test(
      'resolves transfer flow and category metadata from account lookup',
      () {
        final item = _item(
          businessPurpose: BusinessPurpose.transfer,
          impactsByAccountId: const {
            'cash': TransactionAccountImpact(
              debitAmount: Money(minorUnits: 0),
              creditAmount: Money(minorUnits: 1234),
              netChange: Money(minorUnits: -1234),
            ),
            'card': TransactionAccountImpact(
              debitAmount: Money(minorUnits: 1234),
              creditAmount: Money(minorUnits: 0),
              netChange: Money(minorUnits: 1234),
            ),
          },
        );

        final row = buildTransactionRowPresentation(
          item: item,
          accountLookup: _lookup,
        );

        expect(row.accountFlow.out?.label, '现金');
        expect(row.accountFlow.in_?.label, '银行卡');
      },
    );

    test('reflects account metadata changes without rebuilding read model', () {
      final item = _item();
      final renamedLookup = AccountLookup({
        ..._accounts,
        'food': _account(
          'food',
          '外食',
          type: AccountType.expense,
          iconKey: 'fork',
        ),
      });

      final row = buildTransactionRowPresentation(
        item: item,
        accountLookup: renamedLookup,
      );

      expect(row.title, '外食');
      expect(row.iconKey, 'fork');
    });

    test('formats home comparison captions per selected period metric', () {
      CashflowSummaryPresentation buildFor(CashflowPeriodMetric metric) {
        return buildMonthlySummaryPresentation(
          const CashflowComparison(
            current: CashflowSummary(
              income: Money(minorUnits: 12400 * 100),
              expense: Money(minorUnits: 3000 * 100),
            ),
            previousSamePeriod: CashflowSummary(
              income: Money(minorUnits: 0),
              expense: Money(minorUnits: 6200 * 100),
            ),
            previousFullPeriod: CashflowSummary(
              income: Money(minorUnits: 6200 * 100),
              expense: Money(minorUnits: 5000 * 100),
            ),
          ),
          metric: metric,
        );
      }

      final delta = buildFor(CashflowPeriodMetric.periodDelta);
      expect(delta.metrics[0].caption, '较上月同期 +1.24万');
      expect(delta.metrics[1].caption, '较上月同期 -3200');

      final ratio = buildFor(CashflowPeriodMetric.periodRatio);
      expect(ratio.metrics[0].caption, '较上月同期 --%');
      expect(ratio.metrics[1].caption, '较上月同期 -52%');

      final previousMonth = buildFor(CashflowPeriodMetric.previousMonthRatio);
      expect(previousMonth.metrics[0].caption, '已达上月 200%');
      expect(previousMonth.metrics[1].caption, '已达上月 60%');
    });

    test('shows flat caption for unchanged same-period amount', () {
      final presentation = buildMonthlySummaryPresentation(
        const CashflowComparison(
          current: CashflowSummary(
            income: Money(minorUnits: 1000 * 100),
            expense: Money(minorUnits: 0),
          ),
          previousSamePeriod: CashflowSummary(
            income: Money(minorUnits: 1000 * 100),
            expense: Money(minorUnits: 0),
          ),
          previousFullPeriod: CashflowSummary(
            income: Money(minorUnits: 1000 * 100),
            expense: Money(minorUnits: 0),
          ),
        ),
        metric: CashflowPeriodMetric.periodDelta,
      );

      expect(presentation.metrics[0].caption, '与上月同期持平');
    });

    test('shows signed remaining budget and used percentage', () {
      final presentation = buildMonthlySummaryPresentation(
        const CashflowComparison(
          current: CashflowSummary(
            income: Money(minorUnits: 0),
            expense: Money(minorUnits: 0),
          ),
          previousSamePeriod: CashflowSummary(
            income: Money(minorUnits: 0),
            expense: Money(minorUnits: 0),
          ),
          previousFullPeriod: CashflowSummary(
            income: Money(minorUnits: 0),
            expense: Money(minorUnits: 0),
          ),
        ),
        totalBudget: BudgetProgress(
          id: 'total',
          name: '总预算',
          budget: const Money(minorUnits: 100000),
          spent: const Money(minorUnits: 120000),
          sortOrder: 0,
          trend: const [],
        ),
        metric: CashflowPeriodMetric.periodDelta,
      );

      final budget = presentation.metrics[2];
      expect(budget.label, '剩余预算');
      expect(budget.amount, const Money(minorUnits: -20000));
      expect(budget.caption, '120%/1000');
    });
  });
}

final _accounts = <String, Account>{
  'cash': _account('cash', '现金', iconKey: 'cash'),
  'card': _account('card', '银行卡', iconKey: 'card'),
  'food': _account('food', '餐饮', type: AccountType.expense, iconKey: 'meal'),
};
final _lookup = AccountLookup(_accounts);

TransactionReadModel _item({
  String id = 'tx-1',
  DateTime? occurredAt,
  BusinessPurpose businessPurpose = BusinessPurpose.dailyExpense,
  Money primaryAmount = const Money(minorUnits: 1234),
  bool isExcludedFromStats = false,
  Money? refundedTotal,
  Money? reimbursementReceivedTotal,
  String? categoryAccountId = 'food',
  Map<String, TransactionAccountImpact>? impactsByAccountId,
  List<TransactionAdjustment> adjustments = const [],
}) {
  return TransactionReadModel(
    id: id,
    businessPurpose: businessPurpose,
    occurredAt: occurredAt ?? DateTime(2026, 1, 1, 8, 30),
    primaryAmount: primaryAmount,
    isExcludedFromStats: isExcludedFromStats,
    isExcludedFromBudget: false,
    lines: [
      if (categoryAccountId != null)
        TransactionLine(
          id: '$id-category',
          transactionId: id,
          lineNo: 1,
          role: businessPurpose == BusinessPurpose.reimbursementAdvance
              ? TransactionRole.reimbursementExpenseCategory
              : TransactionRole.category,
          accountId: categoryAccountId,
          amount: primaryAmount,
        ),
      if (impactsByAccountId?.isNotEmpty ?? true)
        TransactionLine(
          id: '$id-out',
          transactionId: id,
          lineNo: 2,
          role: TransactionRole.settlementOut,
          accountId: 'cash',
          amount: primaryAmount,
        ),
      if (impactsByAccountId?.isNotEmpty ?? true)
        TransactionLine(
          id: '$id-in',
          transactionId: id,
          lineNo: 3,
          role: TransactionRole.settlementIn,
          accountId: 'card',
          amount: primaryAmount,
        ),
      for (final adjustment in adjustments)
        if (switch (adjustment.kind) {
              TransactionAdjustmentKind.transferFee ||
              TransactionAdjustmentKind.repaymentFee => TransactionRole.fee,
              TransactionAdjustmentKind.repaymentInterest ||
              TransactionAdjustmentKind.receivableCollectionInterest =>
                TransactionRole.interest,
              TransactionAdjustmentKind.repaymentDiscount =>
                TransactionRole.discount,
              TransactionAdjustmentKind.receivableCollectionPrincipal =>
                TransactionRole.receivable,
              _ => null,
            }
            case final role?)
          TransactionLine(
            id: '$id-${adjustment.kind.name}',
            transactionId: id,
            lineNo: 4,
            role: role,
            accountId: role == TransactionRole.receivable ? 'cash' : null,
            amount: adjustment.amount,
          ),
    ],
    impactsByAccountId:
        impactsByAccountId ??
        {
          'food': TransactionAccountImpact(
            debitAmount: primaryAmount,
            creditAmount: Money.zero(),
            netChange: primaryAmount,
          ),
          'cash': TransactionAccountImpact(
            debitAmount: Money.zero(),
            creditAmount: primaryAmount,
            netChange: Money(minorUnits: -primaryAmount.minorUnits),
          ),
        },
    children: [
      if (refundedTotal != null)
        TransactionReadModel(
          id: '$id-refund',
          parentTransactionId: id,
          businessPurpose: BusinessPurpose.refund,
          occurredAt: occurredAt ?? DateTime(2026, 1, 1),
          primaryAmount: refundedTotal,
          isExcludedFromStats: false,
          isExcludedFromBudget: false,
          lines: [
            TransactionLine(
              id: '$id-refund-settlement',
              transactionId: '$id-refund',
              lineNo: 1,
              role: TransactionRole.settlementIn,
              accountId: 'cash',
              amount: refundedTotal,
            ),
          ],
        ),
      if (reimbursementReceivedTotal != null)
        TransactionReadModel(
          id: '$id-receipt',
          parentTransactionId: id,
          businessPurpose: BusinessPurpose.reimbursementReceipt,
          occurredAt: occurredAt ?? DateTime(2026, 1, 1),
          primaryAmount: reimbursementReceivedTotal,
          isExcludedFromStats: false,
          isExcludedFromBudget: false,
          lines: [
            TransactionLine(
              id: '$id-receipt-settlement',
              transactionId: '$id-receipt',
              lineNo: 1,
              role: TransactionRole.settlementIn,
              accountId: 'cash',
              amount: reimbursementReceivedTotal,
            ),
          ],
        ),
    ],
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
