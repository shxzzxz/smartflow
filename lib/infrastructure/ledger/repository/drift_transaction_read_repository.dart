import 'package:drift/drift.dart';

import '../../../domain/ledger/entity/transaction.dart';
import '../../../domain/ledger/valobj/ledger_enum.dart';
import '../../../application/ledger/query/transaction_queries.dart';
import '../../../application/ledger/query/transaction_read_repository.dart';
import 'package:smartflow/data/app_database.dart';
import '../mapper/transaction_mapper.dart';
import '../sql/balance_expressions.dart';

class DriftTransactionReadRepository implements TransactionReadRepository {
  const DriftTransactionReadRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Transaction?> findById(String id) async {
    final row =
        await (_db.select(_db.transactions)
          ..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : mapTransaction(row);
  }

  @override
  Future<DateTime?> findCreatedAt(String id) async {
    final row =
        await (_db.selectOnly(_db.transactions)
              ..addColumns([_db.transactions.createdAt])
              ..where(_db.transactions.id.equals(id)))
            .getSingleOrNull();
    return row?.read(_db.transactions.createdAt);
  }

  @override
  Future<List<Transaction>> findByIds(Set<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows =
        await (_db.select(_db.transactions)
          ..where((t) => t.id.isIn(ids))).get();
    return rows.map(mapTransaction).toList();
  }

  @override
  Stream<List<Transaction>> watchPage(TransactionListQuery query) {
    final select = _db.select(_db.transactions)..where(
      (t) => applyTransactionScope(
        transactions: _db.transactions,
        scope: query.scope,
      ),
    );

    if (query.topLevelOnly) {
      select.where((t) => t.parentTransactionId.isNull());
    }
    if (query.occurredFrom != null) {
      select.where(
        (t) => t.occurredAt.isBiggerOrEqualValue(query.occurredFrom!),
      );
    }
    if (query.occurredUntil != null) {
      select.where(
        (t) => t.occurredAt.isSmallerThanValue(query.occurredUntil!),
      );
    }
    if (query.accountId != null) {
      final accountSubquery =
          _db.selectOnly(_db.entries, distinct: true)
            ..addColumns([_db.entries.transactionId])
            ..where(_db.entries.accountId.equals(query.accountId!));
      select.where((t) => t.id.isInQuery(accountSubquery));
    }

    select
      ..orderBy([
        (t) => OrderingTerm.desc(t.occurredAt),
        (t) => OrderingTerm.desc(t.id),
      ])
      ..limit(query.limit, offset: query.offset);

    return select.watch().map((rows) => rows.map(mapTransaction).toList());
  }

  @override
  Future<List<Transaction>> findChildren({
    required String parentId,
    Set<BusinessState>? states,
  }) async {
    final select = _db.select(_db.transactions)
      ..where((t) => t.parentTransactionId.equals(parentId));
    if (states != null) {
      select.where((t) => t.businessState.isInValues(states));
    }
    select.orderBy([
      (t) => OrderingTerm.desc(t.occurredAt),
      (t) => OrderingTerm.desc(t.id),
    ]);
    final rows = await select.get();
    return rows.map(mapTransaction).toList();
  }

  @override
  Future<List<Transaction>> findRootDescendants({
    required String rootId,
    String? excludeId,
    ({BusinessState state, MutationKind mutationKind})? excludeStateMutation,
  }) async {
    final rows = await _findRootDescendantRows(
      rootId: rootId,
      excludeId: excludeId,
      excludeStateMutation: excludeStateMutation,
    );
    return rows.map(mapTransaction).toList();
  }

  @override
  Future<List<TransactionHistoryRow>> findRootDescendantHistory({
    required String rootId,
    String? excludeId,
    ({BusinessState state, MutationKind mutationKind})? excludeStateMutation,
  }) async {
    final rows = await _findRootDescendantRows(
      rootId: rootId,
      excludeId: excludeId,
      excludeStateMutation: excludeStateMutation,
    );
    return [
      for (final row in rows)
        TransactionHistoryRow(
          transaction: mapTransaction(row),
          createdAt: row.createdAt,
        ),
    ];
  }

  Future<List<TransactionRow>> _findRootDescendantRows({
    required String rootId,
    String? excludeId,
    ({BusinessState state, MutationKind mutationKind})? excludeStateMutation,
  }) async {
    final select = _db.select(_db.transactions)
      ..where((t) => t.rootTransactionId.equals(rootId));
    if (excludeId != null) {
      select.where((t) => t.id.equals(excludeId).not());
    }
    if (excludeStateMutation != null) {
      // NOT (state == X AND mutation_kind == Y) ≡ state != X OR mutation_kind != Y
      select.where(
        (t) =>
            t.businessState.equalsValue(excludeStateMutation.state).not() |
            t.mutationKind.equalsValue(excludeStateMutation.mutationKind).not(),
      );
    }
    select.orderBy([
      (t) => OrderingTerm.desc(t.createdAt),
      (t) => OrderingTerm.desc(t.id),
    ]);
    return select.get();
  }

  @override
  Future<Map<String, TransactionChildAggregate>> aggregateChildren({
    required Set<String> rootIds,
    required Set<BusinessPurpose> purposes,
    required Set<BusinessState> states,
  }) async {
    if (rootIds.isEmpty || purposes.isEmpty || states.isEmpty) {
      return const {};
    }
    final sumExpr = _db.transactions.primaryAmountMinor.sum();
    final countExpr = _db.transactions.id.count();
    final rootIdCol = _db.transactions.rootTransactionId;

    final select =
        _db.selectOnly(_db.transactions)
          ..addColumns([rootIdCol, sumExpr, countExpr])
          ..where(_db.transactions.rootTransactionId.isIn(rootIds))
          ..where(_db.transactions.businessPurpose.isInValues(purposes))
          ..where(_db.transactions.businessState.isInValues(states))
          ..where(_db.transactions.parentTransactionId.isNotNull())
          ..groupBy([rootIdCol]);

    final rows = await select.get();
    final result = <String, TransactionChildAggregate>{};
    for (final row in rows) {
      final rootId = row.read(rootIdCol);
      if (rootId == null) continue;
      result[rootId] = TransactionChildAggregate(
        sumMinor: row.read(sumExpr) ?? 0,
        count: row.read(countExpr) ?? 0,
      );
    }
    return result;
  }

  @override
  Future<Map<String, Map<TransactionDetailType, int>>>
  aggregateChildDetailAmounts({
    required Set<String> rootIds,
    required Set<TransactionDetailType> detailTypes,
    required Set<BusinessState> states,
  }) async {
    if (rootIds.isEmpty || detailTypes.isEmpty || states.isEmpty) {
      return const {};
    }
    final sumExpr = _db.transactionDetails.amountMinor.sum();
    final rootIdCol = _db.transactions.rootTransactionId;
    final detailTypeCol = _db.transactionDetails.detailType;

    final select =
        _db.selectOnly(_db.transactionDetails).join([
            innerJoin(
              _db.transactions,
              _db.transactions.id.equalsExp(
                _db.transactionDetails.transactionId,
              ),
            ),
          ])
          ..addColumns([rootIdCol, detailTypeCol, sumExpr])
          ..where(_db.transactions.rootTransactionId.isIn(rootIds))
          ..where(_db.transactions.businessState.isInValues(states))
          ..where(_db.transactions.parentTransactionId.isNotNull())
          ..where(_db.transactionDetails.detailType.isInValues(detailTypes))
          ..groupBy([rootIdCol, detailTypeCol]);

    final rows = await select.get();
    final result = <String, Map<TransactionDetailType, int>>{};
    for (final row in rows) {
      final rootId = row.read(rootIdCol);
      final typeName = row.read(detailTypeCol);
      final sum = row.read(sumExpr) ?? 0;
      if (rootId == null || typeName == null) continue;
      final type = TransactionDetailType.values.byName(typeName);
      result.putIfAbsent(rootId, () => <TransactionDetailType, int>{})[type] =
          sum;
    }
    return result;
  }

  @override
  Future<Map<String, Map<BusinessPurpose, TransactionChildAggregate>>>
  aggregateChildrenByPurpose({
    required Set<String> rootIds,
    required Set<BusinessPurpose> purposes,
    required Set<BusinessState> states,
  }) async {
    if (rootIds.isEmpty || purposes.isEmpty || states.isEmpty) {
      return const {};
    }
    final sumExpr = _db.transactions.primaryAmountMinor.sum();
    final countExpr = _db.transactions.id.count();
    final rootIdCol = _db.transactions.rootTransactionId;
    final purposeCol = _db.transactions.businessPurpose;

    final select =
        _db.selectOnly(_db.transactions)
          ..addColumns([rootIdCol, purposeCol, sumExpr, countExpr])
          ..where(_db.transactions.rootTransactionId.isIn(rootIds))
          ..where(_db.transactions.businessPurpose.isInValues(purposes))
          ..where(_db.transactions.businessState.isInValues(states))
          ..where(_db.transactions.parentTransactionId.isNotNull())
          ..groupBy([rootIdCol, purposeCol]);

    final rows = await select.get();
    final result = <String, Map<BusinessPurpose, TransactionChildAggregate>>{};
    for (final row in rows) {
      final rootId = row.read(rootIdCol);
      final purposeName = row.read(purposeCol);
      if (rootId == null || purposeName == null) continue;
      final purpose = BusinessPurpose.values.byName(purposeName);
      final bucket = result.putIfAbsent(
        rootId,
        () => <BusinessPurpose, TransactionChildAggregate>{},
      );
      bucket[purpose] = TransactionChildAggregate(
        sumMinor: row.read(sumExpr) ?? 0,
        count: row.read(countExpr) ?? 0,
      );
    }
    return result;
  }

  @override
  Stream<void> watchChanges() async* {
    yield null;
    await for (final _ in _db.tableUpdates(
      TableUpdateQuery.onAllTables([
        _db.transactions,
        _db.entries,
        _db.transactionDetails,
      ]),
    )) {
      yield null;
    }
  }
}
