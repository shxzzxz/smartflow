import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme_extension.dart';
import 'package:smartflow/application/ledger/ledger_api.dart';
import 'package:smartflow/feature/home/view_model/home_transaction_group.dart';
import 'package:smartflow/feature/home/view_model/transaction_row_presentation.dart';

void main() {
  group('transaction row presentation', () {
    test('uses reimbursement expense category but keeps amount neutral', () {
      final fixture = _buildFixture(
        BusinessPurpose.reimbursementAdvance,
        categoryName: '电费',
        categoryIconKey: 'flashlight-line',
        flowOutName: '信用卡',
        flowInName: '公司报销',
      );

      expect(transactionPrimaryLabel(fixture.item, fixture.accountsById), '电费');
      expect(
        resolveCategoryIconKey(fixture.item, fixture.accountsById),
        'flashlight-line',
      );
      expect(
        transactionAccountLabel(fixture.item, fixture.accountsById),
        '信用卡',
      );
      expect(formatTransactionAmount(fixture.item), '12.34');
      expect(
        amountColor(
          const ColorScheme.light(),
          AppThemeExtension.light(),
          fixture.item.businessPurpose,
        ),
        const ColorScheme.light().onSurface,
      );
      expect(isIncomePurpose(fixture.item.businessPurpose), isFalse);
      expect(isExpensePurpose(fixture.item.businessPurpose), isFalse);
    });

    test('maps non-cashflow main transaction icons and signs', () {
      final borrowing = _buildFixture(BusinessPurpose.borrowing);
      final openingBalance = _buildFixture(BusinessPurpose.openingBalance);
      final balanceAdjustment = _buildFixture(
        BusinessPurpose.balanceAdjustment,
      );

      expect(
        resolveCategoryIconKey(borrowing.item, borrowing.accountsById),
        'hand-coin-line',
      );
      expect(
        resolveCategoryIconKey(
          openingBalance.item,
          openingBalance.accountsById,
        ),
        'wallet-line',
      );
      expect(
        resolveCategoryIconKey(
          balanceAdjustment.item,
          balanceAdjustment.accountsById,
        ),
        'wallet-line',
      );
      expect(formatTransactionAmount(borrowing.item), '12.34');
      expect(isIncomePurpose(borrowing.item.businessPurpose), isFalse);
    });

    test('keeps daily income and expense as signed day totals', () {
      final expense = _buildFixture(BusinessPurpose.dailyExpense);
      final income = _buildFixture(BusinessPurpose.dailyIncome);

      expect(formatTransactionAmount(expense.item), '-12.34');
      expect(formatTransactionAmount(income.item), '+12.34');
      expect(isExpensePurpose(expense.item.businessPurpose), isTrue);
      expect(isIncomePurpose(income.item.businessPurpose), isTrue);
    });

    test('subtracts refunded total from daily expense summary', () {
      final expense = _buildFixture(
        BusinessPurpose.dailyExpense,
        amountMinor: 5800,
        refundedTotal: const Money(minorUnits: 1000),
      );
      final group =
          groupTransactionsByDay(
            [expense.item],
            [
              DailyCashflowSummary(
                date: DateTime(2026, 5, 12),
                income: Money.zero(),
                expense: const Money(minorUnits: 4800),
              ),
            ],
          ).single;

      expect(group.expenseMinor, 4800);
      expect(group.incomeMinor, 0);
    });
  });
}

class _Fixture {
  const _Fixture({required this.item, required this.accountsById});

  final TransactionListItem item;
  final Map<String, Account> accountsById;
}

/// 构造一个 list item + 全套 accountsById,用于驱动新签名的 presentation 函数。
///
/// `categoryName` / `categoryIconKey` 通过 entries 内的 expense/income 账户或
/// `reimbursementExpenseAccountId` 投射;`flowOutName` / `flowInName` 通过结算
/// 账户的 credit / debit entries 投射。
_Fixture _buildFixture(
  BusinessPurpose purpose, {
  String? categoryName,
  String? categoryIconKey,
  String? flowOutName,
  String? flowInName,
  int amountMinor = 1234,
  Money? refundedTotal,
}) {
  final amount = Money(minorUnits: amountMinor);
  final accounts = <int, Account>{};
  final entries = <Entry>[];

  Account makeAccount(
    int id,
    String name,
    AccountType type, {
    String? iconKey,
  }) {
    final account = Account(
      id: id,
      name: name,
      type: type,
      balance: Money.zero(),
      iconKey: iconKey,
    );
    accounts[id] = account;
    return account;
  }

  String? reimbursementExpenseAccountId;
  switch (purpose) {
    case BusinessPurpose.dailyExpense:
      makeAccount(
        10,
        categoryName ?? '类目',
        AccountType.expense,
        iconKey: categoryIconKey,
      );
      makeAccount(20, flowOutName ?? '钱包', AccountType.asset);
      entries.add(
        Entry(
          id: '1',
          transactionId: '1',
          accountId: '10',
          direction: EntryDirection.debit,
          amount: amount,
        ),
      );
      entries.add(
        Entry(
          id: '2',
          transactionId: '1',
          accountId: '20',
          direction: EntryDirection.credit,
          amount: amount,
        ),
      );
    case BusinessPurpose.dailyIncome:
      makeAccount(
        11,
        categoryName ?? '类目',
        AccountType.income,
        iconKey: categoryIconKey,
      );
      makeAccount(21, flowInName ?? '银行卡', AccountType.asset);
      entries.add(
        Entry(
          id: '1',
          transactionId: '1',
          accountId: '21',
          direction: EntryDirection.debit,
          amount: amount,
        ),
      );
      entries.add(
        Entry(
          id: '2',
          transactionId: '1',
          accountId: '11',
          direction: EntryDirection.credit,
          amount: amount,
        ),
      );
    case BusinessPurpose.reimbursementAdvance:
      makeAccount(
        12,
        categoryName ?? '报销类目',
        AccountType.expense,
        iconKey: categoryIconKey,
      );
      makeAccount(22, flowOutName ?? '信用卡', AccountType.asset);
      makeAccount(23, flowInName ?? '公司报销', AccountType.asset);
      reimbursementExpenseAccountId = 12;
      entries.add(
        Entry(
          id: '1',
          transactionId: '1',
          accountId: '23',
          direction: EntryDirection.debit,
          amount: amount,
        ),
      );
      entries.add(
        Entry(
          id: '2',
          transactionId: '1',
          accountId: '22',
          direction: EntryDirection.credit,
          amount: amount,
        ),
      );
    default:
      break;
  }

  final item = TransactionListItem(
    id: purpose.index,
    rootTransactionId: purpose.index,
    businessPurpose: purpose,
    businessState: BusinessState.current,
    occurredAt: DateTime(2026, 5, 12, 8, 30),
    primaryAmount: amount,
    entries: entries,
    details: const [],
    refundedTotal: refundedTotal,
    reimbursementExpenseAccountId: reimbursementExpenseAccountId,
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
  );

  return _Fixture(item: item, accountsById: accounts);
}
