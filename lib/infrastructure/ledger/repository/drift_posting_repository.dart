import 'package:drift/drift.dart';

import '../../../core/patch/patch.dart';
import '../../../domain/ledger/entity/account.dart';
import '../../../domain/ledger/entity/transaction.dart';
import '../../../domain/ledger/valobj/transaction_ownership.dart';
import '../../../domain/ledger/valobj/ledger_enum.dart';
import '../../../domain/ledger/valobj/post_receipt.dart';
import '../../../domain/ledger/port/posting_repository.dart';
import 'package:smartflow/data/app_database.dart';
import '../mapper/account_mapper.dart';

class DriftPostingRepository implements PostingRepository {
  const DriftPostingRepository(this._database);

  final AppDatabase _database;

  @override
  Future<List<Account>> findAccountsByIds(Set<int> ids) async {
    if (ids.isEmpty) {
      return const [];
    }

    final rows =
        await (_database.select(_database.accounts)
          ..where((account) => account.id.isIn(ids))).get();

    return rows.map(mapAccount).toList();
  }

  @override
  Future<PostReceiptResult> saveTransaction(Transaction transaction) async {
    final now = DateTime.now();
    final transactionId = await _database
        .into(_database.transactions)
        .insert(
          TransactionsCompanion.insert(
            businessPurpose: transaction.businessPurpose,
            occurredAt: transaction.occurredAt,
            primaryAmountMinor: transaction.primaryAmount.minorUnits,
            mutationKind: transaction.mutationKind,
            businessState: transaction.businessState,
            sourceKind: transaction.sourceKind,
            ownerType: Value(transaction.ownership?.ownerType),
            ownerId: Value(transaction.ownership?.ownerId),
            ownerRole: Value(transaction.ownership?.ownerRole),
            rootTransactionId: Value(transaction.persistedRootTransactionId),
            counterpartyName: Value(transaction.counterpartyName),
            note: Value(transaction.note),
            parentTransactionId: Value(transaction.parentTransactionId),
            reimbursementExpenseAccountId: Value(
              transaction.reimbursementExpenseAccountId,
            ),
            mutationPreviousTransactionId: Value(
              transaction.mutationPreviousTransactionId,
            ),
            mutationReason: Value(transaction.mutationReason),
            isExcludedFromStats: Value(transaction.isExcludedFromStats),
            isExcludedFromBudget: Value(transaction.isExcludedFromBudget),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    final rootTransactionId =
        transaction.persistedRootTransactionId ?? transactionId;
    if (transaction.persistedRootTransactionId == null) {
      await (_database.update(_database.transactions)
        ..where((transaction) => transaction.id.equals(transactionId))).write(
        TransactionsCompanion(
          rootTransactionId: Value(rootTransactionId),
          updatedAt: Value(now),
        ),
      );
    }

    await _database.batch((batch) {
      batch.insertAll(
        _database.transactionDetails,
        transaction.details.map(
          (detail) => TransactionDetailsCompanion.insert(
            transactionId: transactionId,
            lineNo: detail.lineNo,
            detailType: detail.type,
            amountMinor: detail.amount.minorUnits,
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        ),
      );
      batch.insertAll(
        _database.entries,
        transaction.entries.map(
          (entry) => EntriesCompanion.insert(
            transactionId: transactionId,
            accountId: entry.accountId,
            direction: entry.direction,
            amountMinor: entry.amount.minorUnits,
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        ),
      );
    });

    return PostReceiptResult(
      transactionId: transactionId,
      rootTransactionId: rootTransactionId,
    );
  }

  @override
  Future<void> saveAccounts(Iterable<Account> accounts) {
    return _saveAccounts(accounts, now: DateTime.now());
  }

  @override
  Future<void> updateTransactionState({
    required int transactionId,
    required BusinessState businessState,
  }) async {
    await (_database.update(_database.transactions)
      ..where((t) => t.id.equals(transactionId))).write(
      TransactionsCompanion(
        businessState: Value(businessState),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> updateTransactionMetadata({
    required int transactionId,
    Patch<String>? note,
    bool? isExcludedFromStats,
    bool? isExcludedFromBudget,
  }) async {
    if (note == null &&
        isExcludedFromStats == null &&
        isExcludedFromBudget == null) {
      return;
    }
    final noteValue = switch (note) {
      null => const Value<String?>.absent(),
      // 沿用现有约定：空字符串视作清除，避免存储"空字符串备注"这种半残状态。
      PatchSet<String>(:final value) => Value<String?>(
        value.isEmpty ? null : value,
      ),
      PatchClear<String>() => const Value<String?>(null),
    };
    await (_database.update(_database.transactions)
      ..where((t) => t.id.equals(transactionId))).write(
      TransactionsCompanion(
        note: noteValue,
        isExcludedFromStats:
            isExcludedFromStats == null
                ? const Value.absent()
                : Value(isExcludedFromStats),
        isExcludedFromBudget:
            isExcludedFromBudget == null
                ? const Value.absent()
                : Value(isExcludedFromBudget),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> updateTransactionOwnership({
    required int transactionId,
    required TransactionOwnership ownership,
  }) async {
    await (_database.update(_database.transactions)
      ..where((t) => t.id.equals(transactionId))).write(
      TransactionsCompanion(
        ownerType: Value(ownership.ownerType),
        ownerId: Value(ownership.ownerId),
        ownerRole: Value(ownership.ownerRole),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> updateTransactionBasics({
    required int transactionId,
    DateTime? occurredAt,
    List<EntryAccountReassignment> entryAccountReassignments = const [],
    List<Account> updatedAccounts = const [],
  }) async {
    final now = DateTime.now();
    if (occurredAt != null) {
      await (_database.update(_database.transactions)
        ..where((t) => t.id.equals(transactionId))).write(
        TransactionsCompanion(
          occurredAt: Value(occurredAt),
          updatedAt: Value(now),
        ),
      );
    }

    for (final reassignment in entryAccountReassignments) {
      await _reassignEntryAccount(reassignment, now: now);
    }
    await _saveAccounts(updatedAccounts, now: now);
  }

  Future<void> _reassignEntryAccount(
    EntryAccountReassignment reassignment, {
    required DateTime now,
  }) async {
    if (reassignment.fromAccountId == reassignment.toAccountId) {
      return;
    }

    final accountRows =
        await (_database.select(_database.accounts)..where(
          (a) =>
              a.id.isIn({reassignment.fromAccountId, reassignment.toAccountId}),
        )).get();
    final accountsById = {
      for (final account in accountRows) account.id: account,
    };
    final oldAccount = accountsById[reassignment.fromAccountId];
    final newAccount = accountsById[reassignment.toAccountId];
    if (oldAccount == null || newAccount == null) {
      throw StateError(
        'Cannot reassign entry account because account is missing.',
      );
    }

    final rows = await _entryRowsForReassignment(reassignment);
    for (final row in rows) {
      final entry = row.readTable(_database.entries);
      await (_database.update(_database.entries)
        ..where((e) => e.id.equals(entry.id))).write(
        EntriesCompanion(
          accountId: Value(newAccount.id),
          updatedAt: Value(now),
        ),
      );
      await (_database.update(_database.transactions)..where(
        (t) => t.id.equals(entry.transactionId),
      )).write(TransactionsCompanion(updatedAt: Value(now)));
    }
  }

  Future<void> _saveAccounts(
    Iterable<Account> accounts, {
    required DateTime now,
  }) async {
    for (final account in accounts) {
      await (_database.update(_database.accounts)
        ..where((row) => row.id.equals(account.id))).write(
        AccountsCompanion(
          balanceMinor: Value(account.balance.minorUnits),
          updatedAt: Value(now),
        ),
      );
    }
  }

  Future<List<TypedResult>> _entryRowsForReassignment(
    EntryAccountReassignment reassignment,
  ) {
    final query = _database.select(_database.entries).join([
      innerJoin(
        _database.transactions,
        _database.transactions.id.equalsExp(_database.entries.transactionId),
      ),
    ])..where(_database.entries.accountId.equals(reassignment.fromAccountId));

    final transactionId = reassignment.transactionId;
    final rootTransactionId = reassignment.rootTransactionId;
    if (transactionId != null) {
      query.where(_database.entries.transactionId.equals(transactionId));
    } else {
      query.where(
        _database.transactions.rootTransactionId.equals(rootTransactionId!) &
            _database.transactions.businessState.equalsValue(
              BusinessState.current,
            ),
      );
    }
    return query.get();
  }
}
