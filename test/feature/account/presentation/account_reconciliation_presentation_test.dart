import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/account/presentation/account_reconciliation_presentation.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';

void main() {
  test('derives expected balances and reconciles snapshot-only dates', () {
    final state = AccountReconciliationState(
      currentDays: {
        20260702: DailyAccountLedgerState(
          ledgerDateKey: 20260702,
          latestTransactionUpdatedAt: DateTime(2026, 7, 2, 10),
          transactionCount: 1,
        ),
        20260703: DailyAccountLedgerState(
          ledgerDateKey: 20260703,
          latestTransactionUpdatedAt: DateTime(2026, 7, 4),
          transactionCount: 1,
        ),
        20260705: DailyAccountLedgerState(
          ledgerDateKey: 20260705,
          latestTransactionUpdatedAt: DateTime(2026, 7, 5),
          transactionCount: 1,
        ),
      },
      snapshotDays: {
        20260702: AccountReconciliationDaySnapshot(
          accountId: 'cash',
          ledgerDateKey: 20260702,
          latestTransactionUpdatedAt: DateTime(2026, 7, 2, 10),
          transactionCount: 1,
          confirmedAt: DateTime(2026, 7, 3),
        ),
        20260703: AccountReconciliationDaySnapshot(
          accountId: 'cash',
          ledgerDateKey: 20260703,
          latestTransactionUpdatedAt: DateTime(2026, 7, 3),
          transactionCount: 1,
          confirmedAt: DateTime(2026, 7, 4),
        ),
        20260704: AccountReconciliationDaySnapshot(
          accountId: 'cash',
          ledgerDateKey: 20260704,
          latestTransactionUpdatedAt: DateTime(2026, 7, 4),
          transactionCount: 1,
          confirmedAt: DateTime(2026, 7, 5),
        ),
      },
    );

    final groups = buildAccountReconciliationDayGroups(
      entries: [
        _entry('tx-2', DateTime(2026, 7, 2), 1000),
        _entry('tx-3', DateTime(2026, 7, 3), -2000),
        _entry('tx-5', DateTime(2026, 7, 5), 500),
      ],
      reconciliation: state,
      accountId: 'cash',
      accountLookup: AccountLookup(_accounts),
      expectedBalance: const Money(minorUnits: 10000),
    );

    expect(groups.map((group) => group.date), [
      DateTime(2026, 7, 5),
      DateTime(2026, 7, 4),
      DateTime(2026, 7, 3),
      DateTime(2026, 7, 2),
    ]);
    expect(groups.map((group) => group.closingBalance?.minorUnits), [
      10000,
      null,
      9500,
      11500,
    ]);
    expect(groups.map((group) => group.warning), [
      '新增流水，尚未对账',
      '该日原流水已删除',
      '该日流水与上次确认时不同',
      null,
    ]);
    expect(groups.first.rows.single.amount.preciseText, '+5');
  });
}

TransactionFeedEntry _entry(String id, DateTime occurredAt, int deltaMinor) {
  return TransactionFeedEntry(
    transaction: TransactionReadModel(
      id: id,
      businessPurpose: BusinessPurpose.dailyExpense,
      occurredAt: occurredAt,
      primaryAmount: Money(minorUnits: deltaMinor.abs()),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      lines: [
        TransactionLine(
          id: '$id-category',
          transactionId: id,
          lineNo: 1,
          role: TransactionRole.category,
          accountId: 'food',
          amount: Money(minorUnits: deltaMinor.abs()),
        ),
        TransactionLine(
          id: '$id-settlement',
          transactionId: id,
          lineNo: 2,
          role: TransactionRole.settlementOut,
          accountId: 'cash',
          amount: Money(minorUnits: deltaMinor.abs()),
        ),
      ],
      impactsByAccountId: {
        'cash': TransactionAccountImpact(
          debitAmount: Money(minorUnits: deltaMinor > 0 ? deltaMinor : 0),
          creditAmount: Money(minorUnits: deltaMinor < 0 ? -deltaMinor : 0),
          netChange: Money(minorUnits: deltaMinor),
        ),
      },
    ),
  );
}

final _accounts = <String, Account>{
  'cash': Account(
    id: 'cash',
    name: '现金',
    type: AccountType.asset,
    balance: Money.zero(),
  ),
  'food': Account(
    id: 'food',
    name: '餐饮',
    type: AccountType.expense,
    balance: Money.zero(),
  ),
};
