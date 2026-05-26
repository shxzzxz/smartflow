import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/result/result.dart';
import 'package:smartflow/data/app_database.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_posting_repository.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/application/ledger/ledger_api.dart';
import 'package:smartflow/domain/ledger/ledger/ledger_rule.dart';
import 'package:smartflow/domain/ledger/ledger/post_receipt.dart';
import 'package:smartflow/domain/ledger/ledger/poster.dart';

import '../../../helper/test_app_database.dart';

void main() {
  group('DriftPostingRepository', () {
    late AppDatabase database;
    late Poster poster;

    setUp(() {
      database = createTestDatabase();
      poster = PosterImpl(DriftPostingRepository(database));
    });

    tearDown(() async {
      await database.close();
    });

    test('posts a daily expense and updates account balances', () async {
      final walletId = await _insertAccount(
        database,
        name: 'Wallet',
        type: AccountType.asset,
      );
      final foodId = await _insertAccount(
        database,
        name: 'Food',
        type: AccountType.expense,
      );

      final result = await poster.create(
        PostReceipt(
          businessPurpose: BusinessPurpose.dailyExpense,
          occurredAt: DateTime(2026, 5),
          primaryAmount: const Money(minorUnits: 2000),
          details: const [
            ReceiptDetail(
              lineNo: 1,
              type: TransactionDetailType.primaryExpense,
              amount: Money(minorUnits: 2000),
            ),
          ],
          entries: [
            ReceiptEntry(
              accountId: foodId,
              direction: EntryDirection.debit,
              amount: const Money(minorUnits: 2000),
            ),
            ReceiptEntry(
              accountId: walletId,
              direction: EntryDirection.credit,
              amount: const Money(minorUnits: 2000),
            ),
          ],
        ),
      );

      expect(result, isA<Success<PostReceiptResult>>());
      final posted = (result as Success<PostReceiptResult>).value;
      expect(posted.rootTransactionId, posted.transactionId);
      expect(await _balanceOf(database, walletId), -2000);
      expect(await _balanceOf(database, foodId), 2000);
      await _expectStoredBalancesMatchEntries(database);
    });

    test('posts a daily income and updates account balances', () async {
      final bankId = await _insertAccount(
        database,
        name: 'Bank',
        type: AccountType.asset,
      );
      final salaryId = await _insertAccount(
        database,
        name: 'Salary',
        type: AccountType.income,
      );

      final result = await poster.create(
        PostReceipt(
          businessPurpose: BusinessPurpose.dailyIncome,
          occurredAt: DateTime(2026, 5),
          primaryAmount: const Money(minorUnits: 1000000),
          details: const [
            ReceiptDetail(
              lineNo: 1,
              type: TransactionDetailType.primaryIncome,
              amount: Money(minorUnits: 1000000),
            ),
          ],
          entries: [
            ReceiptEntry(
              accountId: bankId,
              direction: EntryDirection.debit,
              amount: const Money(minorUnits: 1000000),
            ),
            ReceiptEntry(
              accountId: salaryId,
              direction: EntryDirection.credit,
              amount: const Money(minorUnits: 1000000),
            ),
          ],
        ),
      );

      expect(result, isA<Success<PostReceiptResult>>());
      expect(await _balanceOf(database, bankId), 1000000);
      expect(await _balanceOf(database, salaryId), 1000000);
      await _expectStoredBalancesMatchEntries(database);
    });

    test('persists transaction ownership when provided', () async {
      final bankId = await _insertAccount(
        database,
        name: 'Bank',
        type: AccountType.asset,
      );
      final debtId = await _insertAccount(
        database,
        name: 'Loan',
        type: AccountType.liability,
      );

      final result = await poster.create(
        PostReceipt(
          businessPurpose: BusinessPurpose.borrowing,
          occurredAt: DateTime(2026, 5),
          primaryAmount: const Money(minorUnits: 100000),
          ownership: const TransactionOwnership(
            ownerType: 'installment',
            ownerId: 42,
            ownerRole: 'disbursement',
          ),
          details: const [
            ReceiptDetail(
              lineNo: 1,
              type: TransactionDetailType.borrowingPrincipal,
              amount: Money(minorUnits: 100000),
            ),
          ],
          entries: [
            ReceiptEntry(
              accountId: bankId,
              direction: EntryDirection.debit,
              amount: const Money(minorUnits: 100000),
            ),
            ReceiptEntry(
              accountId: debtId,
              direction: EntryDirection.credit,
              amount: const Money(minorUnits: 100000),
            ),
          ],
        ),
      );

      final posted = (result as Success<PostReceiptResult>).value;
      final row =
          await (database.select(database.transactions)
            ..where((t) => t.id.equals(posted.transactionId))).getSingle();
      expect(row.ownerType, 'installment');
      expect(row.ownerId, 42);
      expect(row.ownerRole, 'disbursement');
    });

    test('posts a transfer to a liability account', () async {
      final bankId = await _insertAccount(
        database,
        name: 'Bank',
        type: AccountType.asset,
      );
      final cardId = await _insertAccount(
        database,
        name: 'Credit card',
        type: AccountType.liability,
      );

      final result = await poster.create(
        PostReceipt(
          businessPurpose: BusinessPurpose.transfer,
          occurredAt: DateTime(2026, 5),
          primaryAmount: const Money(minorUnits: 50000),
          details: const [
            ReceiptDetail(
              lineNo: 1,
              type: TransactionDetailType.transferMain,
              amount: Money(minorUnits: 50000),
            ),
          ],
          entries: [
            ReceiptEntry(
              accountId: cardId,
              direction: EntryDirection.debit,
              amount: const Money(minorUnits: 50000),
            ),
            ReceiptEntry(
              accountId: bankId,
              direction: EntryDirection.credit,
              amount: const Money(minorUnits: 50000),
            ),
          ],
        ),
      );

      expect(result, isA<Success<PostReceiptResult>>());
      expect(await _balanceOf(database, bankId), -50000);
      expect(await _balanceOf(database, cardId), -50000);
      await _expectStoredBalancesMatchEntries(database);
    });

    test('rejects unbalanced entries without writing rows', () async {
      final walletId = await _insertAccount(
        database,
        name: 'Wallet',
        type: AccountType.asset,
      );
      final foodId = await _insertAccount(
        database,
        name: 'Food',
        type: AccountType.expense,
      );

      final result = await poster.create(
        PostReceipt(
          businessPurpose: BusinessPurpose.dailyExpense,
          occurredAt: DateTime(2026, 5),
          primaryAmount: const Money(minorUnits: 2000),
          details: const [
            ReceiptDetail(
              lineNo: 1,
              type: TransactionDetailType.primaryExpense,
              amount: Money(minorUnits: 2000),
            ),
          ],
          entries: [
            ReceiptEntry(
              accountId: foodId,
              direction: EntryDirection.debit,
              amount: const Money(minorUnits: 2000),
            ),
            ReceiptEntry(
              accountId: walletId,
              direction: EntryDirection.credit,
              amount: const Money(minorUnits: 1900),
            ),
          ],
        ),
      );

      expect(result, isA<FailureResult<PostReceiptResult>>());
      expect(await _countRows(database, 'transactions'), 0);
      expect(await _countRows(database, 'transaction_details'), 0);
      expect(await _countRows(database, 'entries'), 0);
      expect(await _balanceOf(database, walletId), 0);
      expect(await _balanceOf(database, foodId), 0);
    });

    test('rejects zero primary amount without writing rows', () async {
      final walletId = await _insertAccount(
        database,
        name: 'Wallet',
        type: AccountType.asset,
      );
      final foodId = await _insertAccount(
        database,
        name: 'Food',
        type: AccountType.expense,
      );

      final result = await poster.create(
        PostReceipt(
          businessPurpose: BusinessPurpose.dailyExpense,
          occurredAt: DateTime(2026, 5),
          primaryAmount: const Money(minorUnits: 0),
          details: const [
            ReceiptDetail(
              lineNo: 1,
              type: TransactionDetailType.primaryExpense,
              amount: Money(minorUnits: 2000),
            ),
          ],
          entries: [
            ReceiptEntry(
              accountId: foodId,
              direction: EntryDirection.debit,
              amount: const Money(minorUnits: 2000),
            ),
            ReceiptEntry(
              accountId: walletId,
              direction: EntryDirection.credit,
              amount: const Money(minorUnits: 2000),
            ),
          ],
        ),
      );

      expect(result, isA<FailureResult<PostReceiptResult>>());
      expect(await _countRows(database, 'transactions'), 0);
      expect(await _countRows(database, 'transaction_details'), 0);
      expect(await _countRows(database, 'entries'), 0);
    });

    test('rejects negative amounts on create path', () async {
      final walletId = await _insertAccount(
        database,
        name: 'Wallet',
        type: AccountType.asset,
      );
      final foodId = await _insertAccount(
        database,
        name: 'Food',
        type: AccountType.expense,
      );

      final result = await poster.create(
        PostReceipt(
          businessPurpose: BusinessPurpose.dailyExpense,
          occurredAt: DateTime(2026, 5),
          primaryAmount: const Money(minorUnits: 2000),
          details: const [
            ReceiptDetail(
              lineNo: 1,
              type: TransactionDetailType.primaryExpense,
              amount: Money(minorUnits: -2000),
            ),
          ],
          entries: [
            ReceiptEntry(
              accountId: foodId,
              direction: EntryDirection.debit,
              amount: const Money(minorUnits: -2000),
            ),
            ReceiptEntry(
              accountId: walletId,
              direction: EntryDirection.credit,
              amount: const Money(minorUnits: -2000),
            ),
          ],
        ),
      );

      expect(result, isA<FailureResult<PostReceiptResult>>());
      expect(await _countRows(database, 'transactions'), 0);
      expect(await _countRows(database, 'transaction_details'), 0);
      expect(await _countRows(database, 'entries'), 0);
      expect(await _balanceOf(database, walletId), 0);
      expect(await _balanceOf(database, foodId), 0);
    });

    test('rolls back the whole write when a child insert fails', () async {
      final walletId = await _insertAccount(
        database,
        name: 'Wallet',
        type: AccountType.asset,
        balanceMinor: 10000,
      );
      final foodId = await _insertAccount(
        database,
        name: 'Food',
        type: AccountType.expense,
      );

      final result = await DriftTransactionRunner(database).run(
        () => poster.create(
          PostReceipt(
            businessPurpose: BusinessPurpose.dailyExpense,
            occurredAt: DateTime(2026, 5),
            primaryAmount: const Money(minorUnits: 2000),
            details: const [
              ReceiptDetail(
                lineNo: 1,
                type: TransactionDetailType.primaryExpense,
                amount: Money(minorUnits: 1000),
              ),
              ReceiptDetail(
                lineNo: 1,
                type: TransactionDetailType.primaryExpense,
                amount: Money(minorUnits: 1000),
              ),
            ],
            entries: [
              ReceiptEntry(
                accountId: foodId,
                direction: EntryDirection.debit,
                amount: const Money(minorUnits: 2000),
              ),
              ReceiptEntry(
                accountId: walletId,
                direction: EntryDirection.credit,
                amount: const Money(minorUnits: 2000),
              ),
            ],
          ),
        ),
      );

      expect(result, isA<FailureResult<PostReceiptResult>>());
      expect(await _countRows(database, 'transactions'), 0);
      expect(await _countRows(database, 'transaction_details'), 0);
      expect(await _countRows(database, 'entries'), 0);
      expect(await _balanceOf(database, walletId), 10000);
      expect(await _balanceOf(database, foodId), 0);
    });
  });
}

Future<int> _insertAccount(
  AppDatabase database, {
  required String name,
  required AccountType type,
  int balanceMinor = 0,
}) {
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          name: name,
          accountType: type,
          balanceMinor: Value(balanceMinor),
        ),
      );
}

Future<int> _balanceOf(AppDatabase database, int accountId) async {
  final row =
      await (database.select(database.accounts)
        ..where((account) => account.id.equals(accountId))).getSingle();
  return row.balanceMinor;
}

Future<int> _countRows(AppDatabase database, String tableName) async {
  final row =
      await database
          .customSelect('SELECT COUNT(*) AS count FROM $tableName')
          .getSingle();
  return row.read<int>('count');
}

Future<void> _expectStoredBalancesMatchEntries(AppDatabase database) async {
  final accounts = await database.select(database.accounts).get();
  final accountTypes = {
    for (final account in accounts) account.id: account.accountType,
  };
  final derivedBalances = {for (final account in accounts) account.id: 0};
  final entries = await database.select(database.entries).get();

  for (final entry in entries) {
    derivedBalances.update(
      entry.accountId,
      (value) =>
          value +
          balanceDeltaMinor(
            accountType: accountTypes[entry.accountId]!,
            direction: entry.direction,
            amountMinor: entry.amountMinor,
          ),
    );
  }

  for (final account in accounts) {
    expect(
      account.balanceMinor,
      derivedBalances[account.id],
      reason: 'account ${account.id} stored balance should match entries',
    );
  }
}
