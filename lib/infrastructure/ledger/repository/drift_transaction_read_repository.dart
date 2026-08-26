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
    final row = await (_db.select(
      _db.transactions,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : mapTransaction(row);
  }

  @override
  Future<Map<String, DateTime>> findCreatedAtByIds(Set<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows =
        await (_db.selectOnly(_db.transactions)
              ..addColumns([_db.transactions.id, _db.transactions.createdAt])
              ..where(_db.transactions.id.isIn(ids)))
            .get();
    return {
      for (final row in rows)
        if (row.read(_db.transactions.id) case final String id)
          if (row.read(_db.transactions.createdAt)
              case final DateTime createdAt)
            id: createdAt,
    };
  }

  @override
  Future<List<Transaction>> findByIds(Set<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await (_db.select(
      _db.transactions,
    )..where((table) => table.id.isIn(ids))).get();
    return rows.map(mapTransaction).toList();
  }

  @override
  Stream<List<Transaction>> watchPage(TransactionPageQuery query) {
    final select = _db.select(_db.transactions)
      ..where(
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
    _andEntryMatch(select, query.categoryAccountIds);
    _andEntryMatch(select, query.settlementAccountIds);
    _andTagMatch(select, query);
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

  /// 每个筛选维度一个独立分录子查询；多个维度叠加即分录条件取交集。
  void _andEntryMatch(
    SimpleSelectStatement<$TransactionsTable, TransactionRow> select,
    Set<String>? accountIds,
  ) {
    if (accountIds == null) return;
    select.where((_) => _entryAccountMatch(accountIds));
  }

  /// 标签维度：事件级匹配。标签只挂在顶层交易上，子交易经
  /// `parent_transaction_id` 继承所属交易组的标签。
  void _andTagMatch(
    SimpleSelectStatement<$TransactionsTable, TransactionRow> select,
    TransactionPageQuery query,
  ) {
    final tagIds = query.tagIds;
    if (tagIds != null) {
      select.where((_) => _taggedTransactionMatch(tagIds));
    } else if (query.untaggedOnly) {
      select.where((_) => _untaggedTransactionMatch());
    }
  }

  Expression<bool> _taggedTransactionMatch(Set<String> tagIds) {
    final transactions = _db.transactions;
    final taggedGroupRoots = _db.selectOnly(_db.transactionTags, distinct: true)
      ..addColumns([_db.transactionTags.transactionId])
      ..where(_db.transactionTags.tagId.isIn(tagIds));
    return (transactions.parentTransactionId.isNull() &
            transactions.id.isInQuery(taggedGroupRoots)) |
        (transactions.parentTransactionId.isNotNull() &
            transactions.parentTransactionId.isInQuery(taggedGroupRoots));
  }

  Expression<bool> _untaggedTransactionMatch() {
    final transactions = _db.transactions;
    final taggedGroupRoots = _db.selectOnly(_db.transactionTags, distinct: true)
      ..addColumns([_db.transactionTags.transactionId]);
    return (transactions.parentTransactionId.isNull() &
            transactions.id.isNotInQuery(taggedGroupRoots)) |
        (transactions.parentTransactionId.isNotNull() &
            transactions.parentTransactionId.isNotInQuery(taggedGroupRoots));
  }

  @override
  Future<Map<String, List<Transaction>>> findChildrenByParentIds(
    Set<String> parentIds,
  ) async {
    if (parentIds.isEmpty) return const {};
    final rows =
        await (_db.select(_db.transactions)
              ..where((table) => table.parentTransactionId.isIn(parentIds))
              ..orderBy([
                (table) => OrderingTerm.desc(table.occurredAt),
                (table) => OrderingTerm.desc(table.id),
              ]))
            .get();
    final result = <String, List<Transaction>>{};
    for (final row in rows) {
      final parentId = row.parentTransactionId;
      if (parentId == null) continue;
      result.putIfAbsent(parentId, () => []).add(mapTransaction(row));
    }
    return result;
  }

  @override
  Future<List<TransactionCleanupTarget>> findCleanupTargets(
    TransactionCleanupQuery query,
  ) async {
    final owned = _cleanupGroupOwnedExpression();
    final select = _db.selectOnly(_db.transactions)
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
          innerJoin(members, members.id.equalsExp(_db.entries.transactionId)),
        ])
        ..addColumns([_db.entries.id])
        ..where(
          _db.entries.accountId.equals(categoryId) &
              (members.id.equalsExp(_db.transactions.id) |
                  members.parentTransactionId.equalsExp(_db.transactions.id)),
        ),
    );
    final groupLineMatch = existsQuery(
      _db.selectOnly(_db.transactionLines).join([
          innerJoin(
            members,
            members.id.equalsExp(_db.transactionLines.transactionId),
          ),
        ])
        ..addColumns([_db.transactionLines.id])
        ..where(
          _db.transactionLines.accountId.equals(categoryId) &
              (members.id.equalsExp(_db.transactions.id) |
                  members.parentTransactionId.equalsExp(_db.transactions.id)),
        ),
    );
    final purposeColumn = _db.transactions.businessPurpose;
    final select = _db.selectOnly(_db.transactions)
      ..addColumns([_db.transactions.id, purposeColumn])
      ..where(
        _db.transactions.parentTransactionId.isNull() &
            (groupLineMatch | groupEntryMatch),
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
  Future<Transaction?> findLatestByCategory(
    CategoryTransactionQuery query,
  ) async {
    final categoryEntryMatch = existsQuery(
      _db.selectOnly(_db.entries)
        ..addColumns([_db.entries.id])
        ..where(
          _db.entries.transactionId.equalsExp(_db.transactions.id) &
              _db.entries.accountId.equals(query.categoryId),
        ),
    );
    final categoryLineMatch = existsQuery(
      _db.selectOnly(_db.transactionLines)
        ..addColumns([_db.transactionLines.id])
        ..where(
          _db.transactionLines.transactionId.equalsExp(_db.transactions.id) &
              _db.transactionLines.accountId.equals(query.categoryId),
        ),
    );
    final row =
        await (_db.select(_db.transactions)
              ..where(
                (table) =>
                    switch (query.hierarchy) {
                      TransactionHierarchyFilter.topLevel =>
                        table.parentTransactionId.isNull(),
                      TransactionHierarchyFilter.child =>
                        table.parentTransactionId.isNotNull(),
                    } &
                    (categoryEntryMatch | categoryLineMatch),
              )
              ..orderBy([
                (table) => OrderingTerm.desc(table.occurredAt),
                (table) => OrderingTerm.desc(table.id),
              ])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : mapTransaction(row);
  }

  @override
  Stream<TransactionCleanupPreview> watchCleanupPreview(
    TransactionCleanupQuery query,
  ) {
    final matched = countAll();
    final owned = countAll(filter: _cleanupGroupOwnedExpression());
    final select = _db.selectOnly(_db.transactions)
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
    final transactionIds = query.transactionIds;
    if (transactionIds != null) {
      expression = expression & _db.transactions.id.isIn(transactionIds);
    }
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
    return expression & _entryAccountMatch(accountIds);
  }

  Expression<bool> _entryAccountMatch(Set<String> accountIds) {
    final subquery = _db.selectOnly(_db.entries, distinct: true)
      ..addColumns([_db.entries.transactionId])
      ..where(_db.entries.accountId.isIn(accountIds));
    return _db.transactions.id.isInQuery(subquery);
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
        _db.transactionLines,
        _db.accounts,
      ]),
    )) {
      yield null;
    }
  }
}
