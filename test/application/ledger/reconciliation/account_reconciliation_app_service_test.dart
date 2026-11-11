import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/ledger/reconciliation/port/account_reconciliation_repository.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';

void main() {
  test('confirms the current daily states inside the command range', () async {
    final snapshots = _FakeReconciliationRepository();
    final runner = _FakeRunner();
    final service = AccountReconciliationAppServiceImpl(
      accounts: _FakeAccounts(
        Account(
          id: 'cash',
          name: '现金',
          type: AccountType.asset,
          balance: Money.zero(),
        ),
      ),
      snapshots: snapshots,
      transactionRunner: runner,
    );

    await service.confirm(
      ConfirmAccountReconciliationCommand(
        accountId: 'cash',
        from: DateTime(2026, 7, 1),
        untilInclusive: DateTime(2026, 7, 31),
      ),
    );

    expect(runner.ran, isTrue);
    expect(snapshots.findQuery?.from, DateTime(2026, 7, 1));
    expect(snapshots.findQuery?.untilInclusive, DateTime(2026, 7, 31));
    expect(snapshots.replacedDays, snapshots.currentDays);
    expect(snapshots.confirmedAt, isNotNull);
  });

  test('rejects an inverted range before loading the account', () async {
    final accounts = _FakeAccounts(null);
    final service = AccountReconciliationAppServiceImpl(
      accounts: accounts,
      snapshots: _FakeReconciliationRepository(),
      transactionRunner: _FakeRunner(),
    );

    expect(
      () => service.confirm(
        ConfirmAccountReconciliationCommand(
          accountId: 'cash',
          from: DateTime(2026, 7, 31),
          untilInclusive: DateTime(2026, 7, 1),
        ),
      ),
      throwsA(isA<BusinessException>()),
    );
    expect(accounts.findCount, 0);
  });
}

class _FakeRunner implements TransactionRunner {
  bool ran = false;

  @override
  Future<T> run<T>(Future<T> Function() body) async {
    ran = true;
    return body();
  }
}

class _FakeAccounts implements AccountRepository {
  _FakeAccounts(this.account);

  final Account? account;
  int findCount = 0;

  @override
  Future<Account?> findById(String id) async {
    findCount += 1;
    return account;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeReconciliationRepository implements AccountReconciliationRepository {
  final currentDays = [
    DailyAccountLedgerState(
      ledgerDateKey: 20260702,
      latestTransactionUpdatedAt: DateTime(2026, 7, 2, 12),
      transactionCount: 3,
    ),
  ];
  AccountReconciliationQuery? findQuery;
  Iterable<DailyAccountLedgerState>? replacedDays;
  DateTime? confirmedAt;

  @override
  Future<List<DailyAccountLedgerState>> findCurrentDays(
    AccountReconciliationQuery query,
  ) async {
    findQuery = query;
    return currentDays;
  }

  @override
  Future<void> replaceSnapshots({
    required AccountReconciliationQuery query,
    required Iterable<DailyAccountLedgerState> currentDays,
    required DateTime confirmedAt,
  }) async {
    replacedDays = currentDays;
    this.confirmedAt = confirmedAt;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
