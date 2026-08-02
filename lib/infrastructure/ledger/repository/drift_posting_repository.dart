import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/money/money.dart';
import '../../../domain/ledger/entity/account.dart';
import '../../../domain/ledger/entity/entry.dart';
import '../../../domain/ledger/entity/transaction_group.dart';
import '../../../domain/ledger/entity/transaction.dart';
import '../../../domain/ledger/entity/transaction_detail_record.dart';
import '../../../domain/ledger/port/transaction_group_repository.dart';
import '../../../domain/ledger/port/transaction_repository.dart';
import '../../../domain/ledger/service/mutation/transaction_group_rewrite_plan.dart';
import '../../database/app_database.dart';
import '../mapper/account_mapper.dart';
import '../mapper/transaction_mapper.dart';

class DriftPostingRepository
    implements TransactionRepository, TransactionGroupRepository {
  const DriftPostingRepository(this._database);

  final AppDatabase _database;

  static const _uuid = Uuid();

  Future<List<Account>> findAccountsByIds(Set<String> ids) async {
    if (ids.isEmpty) {
      return const [];
    }

    final rows =
        await (_database.select(_database.accounts)
          ..where((account) => account.id.isIn(ids))).get();

    return rows.map(mapAccount).toList();
  }

  @override
  Future<Transaction?> findById(String transactionId) async {
    final row =
        await (_database.select(_database.transactions)
          ..where((row) => row.id.equals(transactionId))).getSingleOrNull();
    return row == null ? null : mapTransaction(row);
  }

  @override
  Future<Transaction?> findCompleteById(String transactionId) async {
    final rows = await _findCompleteTransactionsByIds({transactionId});
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<TransactionGroup?> findByTransactionId(String transactionId) async {
    final tx = await findById(transactionId);
    if (tx == null) return null;
    return findByParentId(tx.parentTransactionId ?? tx.id);
  }

  @override
  Future<TransactionGroup?> findByParentId(String parentTransactionId) async {
    final rows =
        await (_database.select(_database.transactions)..where(
          (row) =>
              row.id.equals(parentTransactionId) |
              row.parentTransactionId.equals(parentTransactionId),
        )).get();
    if (rows.isEmpty) return null;

    final complete = await _findCompleteTransactionsByIds({
      for (final row in rows) row.id,
    });
    Transaction? parent;
    final children = <Transaction>[];
    for (final tx in complete) {
      if (tx.parentTransactionId == null) {
        parent = tx;
      } else {
        children.add(tx);
      }
    }
    if (parent == null) return null;
    return TransactionGroup(
      parentTransaction: parent,
      childTransactions: children,
    );
  }

  @override
  Future<void> save(Transaction transaction) {
    return _saveTransaction(transaction);
  }

  @override
  Future<void> saveAll(Iterable<Transaction> transactions) {
    return Future.forEach<Transaction>(transactions, _saveTransaction);
  }

  @override
  Future<Map<String, int>> countEntriesByAccount(Set<String> accountIds) async {
    if (accountIds.isEmpty) {
      return const {};
    }

    final countExpr = _database.entries.id.count();
    final rows =
        await (_database.selectOnly(_database.entries)
              ..addColumns([_database.entries.accountId, countExpr])
              ..where(_database.entries.accountId.isIn(accountIds))
              ..groupBy([_database.entries.accountId]))
            .get();
    return {
      for (final row in rows)
        row.read(_database.entries.accountId)!: row.read(countExpr) ?? 0,
    };
  }

  @override
  Future<void> applyRewrite(TransactionGroupRewritePlan plan) async {
    await Future.forEach<Transaction>(plan.rowUpdates, updateTransaction);
    await Future.forEach<TransactionRewrite>(
      plan.rewrites,
      (rewrite) => _rewriteTransaction(rewrite.after),
    );
  }

  @override
  Future<void> deleteGroup(String parentTransactionId) async {
    final rows =
        await (_database.selectOnly(_database.transactions)
              ..addColumns([_database.transactions.id])
              ..where(
                _database.transactions.id.equals(parentTransactionId) |
                    _database.transactions.parentTransactionId.equals(
                      parentTransactionId,
                    ),
              ))
            .get();
    await _deleteTransactions({
      for (final row in rows) row.read(_database.transactions.id)!,
    });
  }

  @override
  Future<void> deleteChild(String childTransactionId) {
    return _deleteTransactions({childTransactionId});
  }

  Future<void> _deleteTransactions(Set<String> transactionIds) async {
    if (transactionIds.isEmpty) return;
    await (_database.delete(_database.entries)
      ..where((row) => row.transactionId.isIn(transactionIds))).go();
    await (_database.delete(_database.transactionDetails)
      ..where((row) => row.transactionId.isIn(transactionIds))).go();
    await (_database.delete(_database.transactions)
      ..where((row) => row.id.isIn(transactionIds))).go();
  }

  Future<void> _saveTransaction(Transaction transaction) async {
    final exists =
        await (_database.selectOnly(_database.transactions)
              ..addColumns([_database.transactions.id])
              ..where(_database.transactions.id.equals(transaction.id)))
            .getSingleOrNull();
    if (exists != null) {
      await updateTransaction(transaction);
      await _syncTransactionLines(transaction, now: DateTime.now());
      return;
    }

    final now = DateTime.now();
    final transactionId = transaction.id;
    await _database
        .into(_database.transactions)
        .insert(
          TransactionsCompanion.insert(
            id: transactionId,
            businessPurpose: transaction.businessPurpose,
            occurredAt: transaction.occurredAt,
            postedAt: transaction.postedAt,
            primaryAmountMinor: transaction.primaryAmount.minorUnits,
            sourceKind: transaction.sourceKind,
            ownerType: Value(transaction.ownership?.ownerType),
            ownerId: Value(transaction.ownership?.ownerId),
            ownerRole: Value(transaction.ownership?.ownerRole),
            counterpartyName: Value(transaction.counterpartyName),
            note: Value(transaction.note),
            parentTransactionId: Value(transaction.parentTransactionId),
            reimbursementExpenseAccountId: Value(
              transaction.reimbursementExpenseAccountId,
            ),
            isExcludedFromStats: Value(transaction.isExcludedFromStats),
            isExcludedFromBudget: Value(transaction.isExcludedFromBudget),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    await _database.batch((batch) {
      batch.insertAll(
        _database.transactionDetails,
        transaction.details.map(
          (detail) => TransactionDetailsCompanion.insert(
            id: detail.id.isEmpty ? _uuid.v7() : detail.id,
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
            id: entry.id.isEmpty ? _uuid.v7() : entry.id,
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
  }

  Future<void> _rewriteTransaction(Transaction transaction) async {
    await updateTransaction(transaction);
    await (_database.delete(_database.entries)
      ..where((row) => row.transactionId.equals(transaction.id))).go();
    await (_database.delete(_database.transactionDetails)
      ..where((row) => row.transactionId.equals(transaction.id))).go();

    final now = DateTime.now();
    await _database.batch((batch) {
      batch.insertAll(
        _database.transactionDetails,
        transaction.details.map(
          (detail) => TransactionDetailsCompanion.insert(
            id: detail.id.isEmpty ? _uuid.v7() : detail.id,
            transactionId: transaction.id,
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
            id: entry.id.isEmpty ? _uuid.v7() : entry.id,
            transactionId: transaction.id,
            accountId: entry.accountId,
            direction: entry.direction,
            amountMinor: entry.amount.minorUnits,
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        ),
      );
    });
  }

  Future<void> _syncTransactionLines(
    Transaction transaction, {
    required DateTime now,
  }) async {
    for (final detail in transaction.details) {
      await _upsertDetail(transaction.id, detail, now: now);
    }
    for (final entry in transaction.entries) {
      await _upsertEntry(transaction.id, entry, now: now);
    }
  }

  Future<void> _upsertDetail(
    String transactionId,
    TransactionDetailRecord detail, {
    required DateTime now,
  }) async {
    final detailId = detail.id.isEmpty ? _uuid.v7() : detail.id;
    final exists =
        await (_database.selectOnly(_database.transactionDetails)
              ..addColumns([_database.transactionDetails.id])
              ..where(_database.transactionDetails.id.equals(detailId)))
            .getSingleOrNull();
    if (exists == null) {
      await _database
          .into(_database.transactionDetails)
          .insert(
            TransactionDetailsCompanion.insert(
              id: detailId,
              transactionId: transactionId,
              lineNo: detail.lineNo,
              detailType: detail.type,
              amountMinor: detail.amount.minorUnits,
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      return;
    }
    await (_database.update(_database.transactionDetails)
      ..where((row) => row.id.equals(detailId))).write(
      TransactionDetailsCompanion(
        transactionId: Value(transactionId),
        lineNo: Value(detail.lineNo),
        detailType: Value(detail.type),
        amountMinor: Value(detail.amount.minorUnits),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> _upsertEntry(
    String transactionId,
    Entry entry, {
    required DateTime now,
  }) async {
    final entryId = entry.id.isEmpty ? _uuid.v7() : entry.id;
    final exists =
        await (_database.selectOnly(_database.entries)
              ..addColumns([_database.entries.id])
              ..where(_database.entries.id.equals(entryId)))
            .getSingleOrNull();
    if (exists == null) {
      await _database
          .into(_database.entries)
          .insert(
            EntriesCompanion.insert(
              id: entryId,
              transactionId: transactionId,
              accountId: entry.accountId,
              direction: entry.direction,
              amountMinor: entry.amount.minorUnits,
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      return;
    }
    await (_database.update(_database.entries)
      ..where((row) => row.id.equals(entryId))).write(
      EntriesCompanion(
        transactionId: Value(transactionId),
        accountId: Value(entry.accountId),
        direction: Value(entry.direction),
        amountMinor: Value(entry.amount.minorUnits),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> updateTransaction(Transaction transaction) async {
    final now = DateTime.now();
    await (_database.update(_database.transactions)
      ..where((t) => t.id.equals(transaction.id))).write(
      TransactionsCompanion(
        businessPurpose: Value(transaction.businessPurpose),
        occurredAt: Value(transaction.occurredAt),
        postedAt: Value(transaction.postedAt),
        primaryAmountMinor: Value(transaction.primaryAmount.minorUnits),
        sourceKind: Value(transaction.sourceKind),
        ownerType: Value(transaction.ownership?.ownerType),
        ownerId: Value(transaction.ownership?.ownerId),
        ownerRole: Value(transaction.ownership?.ownerRole),
        counterpartyName: Value(transaction.counterpartyName),
        note: Value(transaction.note),
        parentTransactionId: Value(transaction.parentTransactionId),
        reimbursementExpenseAccountId: Value(
          transaction.reimbursementExpenseAccountId,
        ),
        isExcludedFromStats: Value(transaction.isExcludedFromStats),
        isExcludedFromBudget: Value(transaction.isExcludedFromBudget),
        updatedAt: Value(now),
      ),
    );
  }

  Future<List<Transaction>> _findCompleteTransactionsByIds(
    Set<String> ids,
  ) async {
    if (ids.isEmpty) return const [];
    final rows =
        await (_database.select(_database.transactions)
          ..where((row) => row.id.isIn(ids))).get();
    if (rows.isEmpty) return const [];

    final entryRows =
        await (_database.select(_database.entries)
              ..where((row) => row.transactionId.isIn(ids))
              ..orderBy([(row) => OrderingTerm.asc(row.id)]))
            .get();
    final detailRows =
        await (_database.select(_database.transactionDetails)
              ..where((row) => row.transactionId.isIn(ids))
              ..orderBy([(row) => OrderingTerm.asc(row.lineNo)]))
            .get();

    final entriesByTx = <String, List<Entry>>{};
    for (final row in entryRows) {
      entriesByTx
          .putIfAbsent(row.transactionId, () => <Entry>[])
          .add(
            Entry(
              id: row.id,
              transactionId: row.transactionId,
              accountId: row.accountId,
              direction: row.direction,
              amount: Money(minorUnits: row.amountMinor),
            ),
          );
    }
    final detailsByTx = <String, List<TransactionDetailRecord>>{};
    for (final row in detailRows) {
      detailsByTx
          .putIfAbsent(row.transactionId, () => <TransactionDetailRecord>[])
          .add(
            TransactionDetailRecord(
              id: row.id,
              transactionId: row.transactionId,
              lineNo: row.lineNo,
              type: row.detailType,
              amount: Money(minorUnits: row.amountMinor),
            ),
          );
    }
    return [
      for (final row in rows)
        mapTransaction(row).copyWith(
          details: List.unmodifiable(detailsByTx[row.id] ?? const []),
          entries: List.unmodifiable(entriesByTx[row.id] ?? const []),
        ),
    ];
  }
}
