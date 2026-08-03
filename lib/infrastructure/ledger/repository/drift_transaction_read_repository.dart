import 'package:drift/drift.dart';

import '../../../application/ledger/ledger_query_port_api.dart';
import '../../../domain/ledger/entity/transaction.dart';
import '../../../domain/ledger/valobj/ledger_enum.dart';
import '../../database/app_database.dart';
import '../mapper/transaction_mapper.dart';
import '../sql/balance_expressions.dart';

class DriftTransactionReadRepository implements TransactionReadRepository {
  const DriftTransactionReadRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Transaction?> findById(String id) async {
    final row =
        await (_db.select(_db.transactions)
          ..where((table) => table.id.equals(id))).getSingleOrNull();
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
          ..where((table) => table.id.isIn(ids))).get();
    return rows.map(mapTransaction).toList();
  }

  @override
  Stream<List<Transaction>> watchPage(TransactionListQuery query) {
    final select = _db.select(_db.transactions)..where(
      (table) => applyTransactionScope(
        transactions: _db.transactions,
        scope: query.scope,
      ),
    );
    if (query.topLevelOnly) {
      select.where((table) => table.parentTransactionId.isNull());
    }
    if (query.occurredFrom != null) {
      select.where(
        (table) => table.occurredAt.isBiggerOrEqualValue(query.occurredFrom!),
      );
    }
    if (query.occurredUntil != null) {
      select.where(
        (table) => table.occurredAt.isSmallerThanValue(query.occurredUntil!),
      );
    }
    final before = query.before;
    if (before != null) {
      select.where(
        (table) =>
            table.occurredAt.isSmallerThanValue(before.occurredAt) |
            (table.occurredAt.equals(before.occurredAt) &
                table.id.isSmallerThanValue(before.id)),
      );
    }
    final accountIds =
        query.accountIds ??
        (query.accountId == null ? null : <String>{query.accountId!});
    if (accountIds != null) {
      final subquery =
          _db.selectOnly(_db.entries, distinct: true)
            ..addColumns([_db.entries.transactionId])
            ..where(_db.entries.accountId.isIn(accountIds));
      select.where((table) => table.id.isInQuery(subquery));
    }
    select.orderBy([
      (table) => OrderingTerm.desc(table.occurredAt),
      (table) => OrderingTerm.desc(table.id),
    ]);
    final limit = query.limit;
    if (limit != null) {
      select.limit(limit, offset: query.offset);
    }
    return select.watch().map((rows) => rows.map(mapTransaction).toList());
  }

  @override
  Future<List<Transaction>> findChildren({required String parentId}) async {
    final rows =
        await (_db.select(_db.transactions)
              ..where((table) => table.parentTransactionId.equals(parentId))
              ..orderBy([
                (table) => OrderingTerm.desc(table.occurredAt),
                (table) => OrderingTerm.desc(table.id),
              ]))
            .get();
    return rows.map(mapTransaction).toList();
  }

  @override
  Future<Map<String, TransactionChildAggregate>> aggregateChildren({
    required Set<String> parentIds,
    required Set<BusinessPurpose> purposes,
  }) async {
    if (parentIds.isEmpty || purposes.isEmpty) return const {};
    final parentColumn = _db.transactions.parentTransactionId;
    final sumExpression = _db.transactions.primaryAmountMinor.sum();
    final countExpression = _db.transactions.id.count();
    final query =
        _db.selectOnly(_db.transactions)
          ..addColumns([parentColumn, sumExpression, countExpression])
          ..where(parentColumn.isIn(parentIds))
          ..where(_db.transactions.businessPurpose.isInValues(purposes))
          ..groupBy([parentColumn]);
    final result = <String, TransactionChildAggregate>{};
    for (final row in await query.get()) {
      final parentId = row.read(parentColumn);
      if (parentId == null) continue;
      result[parentId] = TransactionChildAggregate(
        sumMinor: row.read(sumExpression) ?? 0,
        count: row.read(countExpression) ?? 0,
      );
    }
    return result;
  }

  @override
  Future<Map<String, Map<TransactionDetailType, int>>>
  aggregateChildDetailAmounts({
    required Set<String> parentIds,
    required Set<TransactionDetailType> detailTypes,
  }) async {
    if (parentIds.isEmpty || detailTypes.isEmpty) return const {};
    final parentColumn = _db.transactions.parentTransactionId;
    final typeColumn = _db.transactionDetails.detailType;
    final sumExpression = _db.transactionDetails.amountMinor.sum();
    final query =
        _db.selectOnly(_db.transactionDetails).join([
            innerJoin(
              _db.transactions,
              _db.transactions.id.equalsExp(
                _db.transactionDetails.transactionId,
              ),
            ),
          ])
          ..addColumns([parentColumn, typeColumn, sumExpression])
          ..where(parentColumn.isIn(parentIds))
          ..where(typeColumn.isInValues(detailTypes))
          ..groupBy([parentColumn, typeColumn]);
    final result = <String, Map<TransactionDetailType, int>>{};
    for (final row in await query.get()) {
      final parentId = row.read(parentColumn);
      final typeName = row.read(typeColumn);
      if (parentId == null || typeName == null) continue;
      result.putIfAbsent(parentId, () => {})[TransactionDetailType.values
              .byName(typeName)] =
          row.read(sumExpression) ?? 0;
    }
    return result;
  }

  @override
  Future<Map<String, Map<BusinessPurpose, TransactionChildAggregate>>>
  aggregateChildrenByPurpose({
    required Set<String> parentIds,
    required Set<BusinessPurpose> purposes,
  }) async {
    if (parentIds.isEmpty || purposes.isEmpty) return const {};
    final parentColumn = _db.transactions.parentTransactionId;
    final purposeColumn = _db.transactions.businessPurpose;
    final sumExpression = _db.transactions.primaryAmountMinor.sum();
    final countExpression = _db.transactions.id.count();
    final query =
        _db.selectOnly(_db.transactions)
          ..addColumns([
            parentColumn,
            purposeColumn,
            sumExpression,
            countExpression,
          ])
          ..where(parentColumn.isIn(parentIds))
          ..where(purposeColumn.isInValues(purposes))
          ..groupBy([parentColumn, purposeColumn]);
    final result = <String, Map<BusinessPurpose, TransactionChildAggregate>>{};
    for (final row in await query.get()) {
      final parentId = row.read(parentColumn);
      final purposeName = row.read(purposeColumn);
      if (parentId == null || purposeName == null) continue;
      result.putIfAbsent(parentId, () => {})[BusinessPurpose.values.byName(
        purposeName,
      )] = TransactionChildAggregate(
        sumMinor: row.read(sumExpression) ?? 0,
        count: row.read(countExpression) ?? 0,
      );
    }
    return result;
  }

  @override
  Future<List<TransactionCleanupTarget>> findCleanupTargets(
    TransactionCleanupQuery query,
  ) async {
    final owned = _cleanupGroupOwnedExpression();
    final select =
        _db.selectOnly(_db.transactions)
          ..addColumns([_db.transactions.id, owned])
          ..where(_cleanupMatchExpression(query))
          ..orderBy([
            OrderingTerm.asc(_db.transactions.occurredAt),
            OrderingTerm.asc(_db.transactions.id),
          ]);
    final rows = await select.get();
    return [
      for (final row in rows)
        TransactionCleanupTarget(
          transactionId: row.read(_db.transactions.id)!,
          owned: row.read(owned) ?? false,
        ),
    ];
  }

  @override
  Future<List<CategoryTransactionTarget>> findCategoryTransactionTargets(
    String categoryId,
  ) async {
    final members = _db.alias(_db.transactions, 'group_members');
    final groupEntryMatch = existsQuery(
      _db.selectOnly(_db.entries).join([
          innerJoin(
            members,
            members.id.equalsExp(_db.entries.transactionId),
          ),
        ])
        ..addColumns([_db.entries.id])
        ..where(
          _db.entries.accountId.equals(categoryId) &
              (members.id.equalsExp(_db.transactions.id) |
                  members.parentTransactionId.equalsExp(_db.transactions.id)),
        ),
    );
    final purposeColumn = _db.transactions.businessPurpose;
    final select =
        _db.selectOnly(_db.transactions)
          ..addColumns([_db.transactions.id, purposeColumn])
          ..where(
            _db.transactions.parentTransactionId.isNull() &
                (_db.transactions.reimbursementExpenseAccountId.equals(
                      categoryId,
                    ) |
                    groupEntryMatch),
          )
          ..orderBy([
            OrderingTerm.asc(_db.transactions.occurredAt),
            OrderingTerm.asc(_db.transactions.id),
          ]);
    final rows = await select.get();
    return [
      for (final row in rows)
        if (row.read(_db.transactions.id) case final String transactionId)
          if (row.read(purposeColumn) case final String purposeName)
            CategoryTransactionTarget(
              transactionId: transactionId,
              businessPurpose: BusinessPurpose.values.byName(purposeName),
            ),
    ];
  }

  @override
  Stream<TransactionCleanupPreview> watchCleanupPreview(
    TransactionCleanupQuery query,
  ) {
    final matched = countAll();
    final owned = countAll(filter: _cleanupGroupOwnedExpression());
    final select =
        _db.selectOnly(_db.transactions)
          ..addColumns([matched, owned])
          ..where(_cleanupMatchExpression(query));
    return select.watchSingle().map(
      (row) => TransactionCleanupPreview(
        matchedGroupCount: row.read(matched) ?? 0,
        ownedGroupCount: row.read(owned) ?? 0,
      ),
    );
  }

  Expression<bool> _cleanupMatchExpression(TransactionCleanupQuery query) {
    Expression<bool> expression = _db.transactions.parentTransactionId.isNull();
    final occurredFrom = query.occurredFrom;
    if (occurredFrom != null) {
      expression =
          expression &
          _db.transactions.occurredAt.isBiggerOrEqualValue(occurredFrom);
    }
    final occurredUntil = query.occurredUntil;
    if (occurredUntil != null) {
      expression =
          expression &
          _db.transactions.occurredAt.isSmallerThanValue(occurredUntil);
    }
    expression = _andEntryAccountMatch(expression, query.categoryIds);
    expression = _andEntryAccountMatch(expression, query.accountIds);
    return expression;
  }

  Expression<bool> _andEntryAccountMatch(
    Expression<bool> expression,
    Set<String>? accountIds,
  ) {
    if (accountIds == null) return expression;
    final subquery =
        _db.selectOnly(_db.entries, distinct: true)
          ..addColumns([_db.entries.transactionId])
          ..where(_db.entries.accountId.isIn(accountIds));
    return expression & _db.transactions.id.isInQuery(subquery);
  }

  Expression<bool> _cleanupGroupOwnedExpression() {
    final members = _db.alias(_db.transactions, 'cleanup_members');
    return existsQuery(
      _db.selectOnly(members)
        ..addColumns([members.id])
        ..where(
          members.ownerType.isNotNull() &
              (members.id.equalsExp(_db.transactions.id) |
                  members.parentTransactionId.equalsExp(_db.transactions.id)),
        ),
    );
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
