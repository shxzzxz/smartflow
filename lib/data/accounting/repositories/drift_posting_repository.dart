import 'package:drift/drift.dart';

import '../../../core/patch/patch.dart';
import '../../../domain/accounting/entities/account.dart';
import '../../../domain/accounting/entities/transaction_ownership.dart';
import '../../../domain/accounting/enums/accounting_enums.dart';
import '../../../domain/accounting/ledger/ledger_rules.dart';
import '../../../domain/accounting/ledger/post_receipt.dart';
import '../../../domain/accounting/repositories/posting_repository.dart';
import '../../app_database.dart';
import '../mappers/account_mapper.dart';

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
              ..where((account) => account.id.isIn(ids)))
            .get();

    return rows.map(mapAccount).toList();
  }

  @override
  Future<PostReceiptResult> insertReceipt({
    required PostReceipt receipt,
    required Map<int, int> balanceDeltasMinor,
    MutationKind mutationKind = MutationKind.original,
    BusinessState businessState = BusinessState.current,
    MutationReason? mutationReason,
    int? mutationPreviousTransactionId,
  }) {
    return _database.transaction(() async {
      return _insertReceiptRow(
        receipt: receipt,
        balanceDeltasMinor: balanceDeltasMinor,
        mutationKind: mutationKind,
        businessState: businessState,
        mutationReason: mutationReason,
        mutationPreviousTransactionId: mutationPreviousTransactionId,
        now: DateTime.now(),
      );
    });
  }

  @override
  Future<PostReceiptResult> replaceTransaction({
    required int originalTransactionId,
    required PostReceipt reversalReceipt,
    required PostReceipt correctionReceipt,
    required Map<int, int> reversalBalanceDeltasMinor,
    required Map<int, int> correctionBalanceDeltasMinor,
  }) {
    return _database.transaction(() async {
      final now = DateTime.now();

      await (_database.update(_database.transactions)
            ..where((t) => t.id.equals(originalTransactionId)))
          .write(
            TransactionsCompanion(
              businessState: const Value(BusinessState.replaced),
              updatedAt: Value(now),
            ),
          );

      final reversal = await _insertReceiptRow(
        receipt: reversalReceipt,
        balanceDeltasMinor: reversalBalanceDeltasMinor,
        mutationKind: MutationKind.reversal,
        businessState: BusinessState.compensation,
        mutationReason: MutationReason.correction,
        mutationPreviousTransactionId: originalTransactionId,
        now: now,
      );

      return _insertReceiptRow(
        receipt: correctionReceipt,
        balanceDeltasMinor: correctionBalanceDeltasMinor,
        mutationKind: MutationKind.correction,
        businessState: BusinessState.current,
        mutationPreviousTransactionId: reversal.transactionId,
        now: now,
      );
    });
  }

  @override
  Future<void> cancelTransactions({
    required List<CancelInstruction> cancellations,
  }) {
    if (cancellations.isEmpty) {
      return Future.value();
    }
    return _database.transaction(() async {
      final now = DateTime.now();
      for (final instruction in cancellations) {
        await (_database.update(_database.transactions)
              ..where((t) => t.id.equals(instruction.originalTransactionId)))
            .write(
              TransactionsCompanion(
                businessState: const Value(BusinessState.canceled),
                updatedAt: Value(now),
              ),
            );
        await _insertReceiptRow(
          receipt: instruction.reversalReceipt,
          balanceDeltasMinor: instruction.balanceDeltasMinor,
          mutationKind: MutationKind.reversal,
          businessState: BusinessState.compensation,
          mutationReason: MutationReason.delete,
          mutationPreviousTransactionId: instruction.originalTransactionId,
          now: now,
        );
      }
    });
  }

  Future<PostReceiptResult> _insertReceiptRow({
    required PostReceipt receipt,
    required Map<int, int> balanceDeltasMinor,
    required MutationKind mutationKind,
    required BusinessState businessState,
    required DateTime now,
    MutationReason? mutationReason,
    int? mutationPreviousTransactionId,
  }) async {
    final transactionId = await _database
        .into(_database.transactions)
        .insert(
          TransactionsCompanion.insert(
            businessPurpose: receipt.businessPurpose,
            occurredAt: receipt.occurredAt,
            currencyCode: receipt.currencyCode,
            primaryAmountMinor: receipt.primaryAmount.minorUnits,
            mutationKind: mutationKind,
            businessState: businessState,
            sourceKind: receipt.sourceKind,
            ownerType: Value(receipt.ownership?.ownerType),
            ownerId: Value(receipt.ownership?.ownerId),
            ownerRole: Value(receipt.ownership?.ownerRole),
            rootTransactionId: Value(receipt.rootTransactionId),
            counterpartyName: Value(receipt.counterpartyName),
            note: Value(receipt.note),
            parentTransactionId: Value(receipt.parentTransactionId),
            reimbursementExpenseAccountId: Value(
              receipt.reimbursementExpenseAccountId,
            ),
            mutationPreviousTransactionId: Value(
              mutationPreviousTransactionId,
            ),
            mutationReason: Value(mutationReason),
            isExcludedFromStats: Value(receipt.isExcludedFromStats),
            isExcludedFromBudget: Value(receipt.isExcludedFromBudget),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    final rootTransactionId = receipt.rootTransactionId ?? transactionId;
    if (receipt.rootTransactionId == null) {
      await (_database.update(_database.transactions)
            ..where((transaction) => transaction.id.equals(transactionId)))
          .write(
            TransactionsCompanion(
              rootTransactionId: Value(rootTransactionId),
              updatedAt: Value(now),
            ),
          );
    }

    await _database.batch((batch) {
      batch.insertAll(
        _database.transactionDetails,
        receipt.details.map(
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
        receipt.entries.map(
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

    for (final MapEntry(key: accountId, value: delta)
        in balanceDeltasMinor.entries) {
      await _applyBalanceDelta(
        accountId: accountId,
        deltaMinor: delta,
        now: now,
      );
    }

    return PostReceiptResult(
      transactionId: transactionId,
      rootTransactionId: rootTransactionId,
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
          ..where((t) => t.id.equals(transactionId)))
        .write(
          TransactionsCompanion(
            note: noteValue,
            isExcludedFromStats: isExcludedFromStats == null
                ? const Value.absent()
                : Value(isExcludedFromStats),
            isExcludedFromBudget: isExcludedFromBudget == null
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
          ..where((t) => t.id.equals(transactionId)))
        .write(
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
  }) {
    return _database.transaction(() async {
      final now = DateTime.now();
      if (occurredAt != null) {
        await (_database.update(_database.transactions)
              ..where((t) => t.id.equals(transactionId)))
            .write(
              TransactionsCompanion(
                occurredAt: Value(occurredAt),
                updatedAt: Value(now),
              ),
            );
      }

      for (final reassignment in entryAccountReassignments) {
        await _reassignEntryAccount(reassignment, now: now);
      }
    });
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
              (a) => a.id.isIn({
                reassignment.fromAccountId,
                reassignment.toAccountId,
              }),
            ))
            .get();
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
    final balanceDeltas = <int, int>{};
    for (final row in rows) {
      final entry = row.readTable(_database.entries);
      final oldDelta = balanceDeltaMinor(
        accountType: oldAccount.accountType,
        direction: entry.direction,
        amountMinor: entry.amountMinor,
      );
      final newDelta = balanceDeltaMinor(
        accountType: newAccount.accountType,
        direction: entry.direction,
        amountMinor: entry.amountMinor,
      );
      balanceDeltas.update(
        oldAccount.id,
        (value) => value - oldDelta,
        ifAbsent: () => -oldDelta,
      );
      balanceDeltas.update(
        newAccount.id,
        (value) => value + newDelta,
        ifAbsent: () => newDelta,
      );

      await (_database.update(_database.entries)
            ..where((e) => e.id.equals(entry.id)))
          .write(
            EntriesCompanion(
              accountId: Value(newAccount.id),
              updatedAt: Value(now),
            ),
          );
      await (_database.update(_database.transactions)
            ..where((t) => t.id.equals(entry.transactionId)))
          .write(TransactionsCompanion(updatedAt: Value(now)));
    }

    for (final MapEntry(key: accountId, value: delta)
        in balanceDeltas.entries) {
      if (delta == 0) continue;
      await _applyBalanceDelta(
        accountId: accountId,
        deltaMinor: delta,
        now: now,
      );
    }
  }

  /// `accounts.balance_minor` 的单一写入口。
  ///
  /// 过账内核(`insertReceipt` / `replaceTransaction` / `cancelTransactions`)
  /// 在事务内调用此方法,domain 层的余额写入语义统一从这里发生 — 切断了
  /// 外部直写 customUpdate 的可能性。
  Future<void> _applyBalanceDelta({
    required int accountId,
    required int deltaMinor,
    required DateTime now,
  }) {
    return _database.customUpdate(
      'UPDATE accounts '
      'SET balance_minor = balance_minor + ?, updated_at = ? '
      'WHERE id = ?',
      variables: [
        Variable<int>(deltaMinor),
        Variable<DateTime>(now),
        Variable<int>(accountId),
      ],
      updates: {_database.accounts},
    );
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
