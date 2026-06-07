import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import 'package:smartflow/widget/business/finance/finance_tone.dart';

void main() {
  group('transaction list presentation', () {
    test('groups transactions with daily summaries by descending date', () {
      final jan1 = DateTime(2026, 1, 1, 8);
      final jan2 = DateTime(2026, 1, 2, 9);

      final groups = groupTransactionsByDay(
        items: [
          _item(id: 'a', occurredAt: jan1),
          _item(id: 'b', occurredAt: jan2),
        ],
        accountLookup: AccountLookup(_accounts),
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

    test('groups controlled row presentations by descending date', () {
      final jan1 = DateTime(2026, 1, 1, 8);
      final jan2 = DateTime(2026, 1, 2, 9);

      final groups = groupTransactionsByDay(
        items: [
          _item(id: 'a', occurredAt: jan1),
          _item(id: 'b', occurredAt: jan2),
        ],
        accountLookup: AccountLookup(_accounts),
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
        accountLookup: AccountLookup(_accounts),
      );

      expect(row.title, '餐饮');
      expect(row.transactionId, 'tx-1');
      expect(row.subtitle, '08:30  午餐');
      expect(row.amountText, '-12.34');
      expect(row.amountTone, FinanceTone.expense);
      expect(row.iconKey, 'meal');
      expect(row.accountFlow.out?.label, '现金');
      expect(row.badges.map((badge) => badge.label), ['不计统计', '退 2.3']);
      expect(row.canQuickEdit, true);
    });

    test('uses account balance delta in account ledger mode', () {
      final row = buildTransactionRowPresentation(
        item: _item(),
        accountLookup: AccountLookup(_accounts),
        viewAccountId: 'cash',
      );

      expect(row.amountText, '-12.34');
      expect(row.amountTone, FinanceTone.neutral);
    });
  });
}

final _accounts = <String, Account>{
  'cash': _account('cash', '现金', iconKey: 'cash'),
  'food': _account('food', '餐饮', type: AccountType.expense, iconKey: 'meal'),
};

TransactionListReadModel _item({
  String id = 'tx-1',
  DateTime? occurredAt,
  bool isExcludedFromStats = false,
  Money? refundedTotal,
}) {
  return TransactionListReadModel(
    id: id,
    rootTransactionId: id,
    businessPurpose: BusinessPurpose.dailyExpense,
    businessState: BusinessState.current,
    occurredAt: occurredAt ?? DateTime(2026, 1, 1, 8, 30),
    primaryAmount: const Money(minorUnits: 1234),
    note: ' 午餐 ',
    isExcludedFromStats: isExcludedFromStats,
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
    refundedTotal: refundedTotal,
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
