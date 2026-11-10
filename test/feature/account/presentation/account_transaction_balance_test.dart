import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/account/presentation/account_transaction_balance.dart';

void main() {
  test('derives closing balances from the newest transaction prefix', () {
    final balances = accountDailyClosingBalances(
      transactions: [
        _transaction(
          'newest',
          DateTime(2026, 7, 14, 18),
          netChangeMinor: 10000,
        ),
        _transaction('older', DateTime(2026, 7, 13, 9), netChangeMinor: -3000),
      ],
      accountId: 'cash',
      currentBalance: const Money(minorUnits: 87000),
    );

    expect(balances[DateTime(2026, 7, 14)]?.minorUnits, 87000);
    expect(balances[DateTime(2026, 7, 13)]?.minorUnits, 77000);
  });

  test('combines all account impacts from the same transaction day', () {
    final balances = accountDailyClosingBalances(
      transactions: [
        _transaction(
          'newest',
          DateTime(2026, 7, 14, 18),
          netChangeMinor: 20000,
        ),
        _transaction('older', DateTime(2026, 7, 14, 9), netChangeMinor: 10000),
        _transaction(
          'previous-day',
          DateTime(2026, 7, 13, 9),
          netChangeMinor: 5000,
        ),
      ],
      accountId: 'cash',
      currentBalance: const Money(minorUnits: 120000),
    );

    expect(balances[DateTime(2026, 7, 14)]?.minorUnits, 120000);
    expect(balances[DateTime(2026, 7, 13)]?.minorUnits, 90000);
  });

  test(
    'keeps the oldest visible day correct when its prefix is incomplete',
    () {
      final balances = accountDailyClosingBalances(
        transactions: [
          _transaction(
            'only-loaded-row',
            DateTime(2026, 7, 14, 18),
            netChangeMinor: 10000,
          ),
        ],
        accountId: 'cash',
        currentBalance: const Money(minorUnits: 87000),
      );

      expect(balances[DateTime(2026, 7, 14)]?.minorUnits, 87000);
    },
  );

  test('ignores transactions without an impact on the account', () {
    final balances = accountDailyClosingBalances(
      transactions: [
        _transaction(
          'other-account-only',
          DateTime(2026, 7, 14, 18),
          netChangeMinor: 10000,
          accountId: 'other',
        ),
      ],
      accountId: 'cash',
      currentBalance: const Money(minorUnits: 87000),
    );

    expect(balances, isEmpty);
  });
}

TransactionReadModel _transaction(
  String id,
  DateTime occurredAt, {
  required int netChangeMinor,
  String accountId = 'cash',
}) {
  return TransactionReadModel(
    id: id,
    businessPurpose: BusinessPurpose.dailyExpense,
    occurredAt: occurredAt,
    primaryAmount: Money(minorUnits: netChangeMinor.abs()),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
    impactsByAccountId: {
      accountId: TransactionAccountImpact(
        debitAmount: Money(minorUnits: netChangeMinor > 0 ? netChangeMinor : 0),
        creditAmount: Money(
          minorUnits: netChangeMinor < 0 ? -netChangeMinor : 0,
        ),
        netChange: Money(minorUnits: netChangeMinor),
      ),
    },
  );
}
