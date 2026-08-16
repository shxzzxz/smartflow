import 'package:drift/drift.dart';

import '../../../application/ledger/tag/tag_read_models.dart';
import '../../../application/ledger/tag/tag_repository.dart';
import '../../database/app_database.dart';

class DriftTransactionTagRepository implements TransactionTagRepository {
  const DriftTransactionTagRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<TagView>> watchTags() {
    final usageCount = _usageCountExpression();
    final select = _tagSelect(usageCount);
    return select.watch().map((rows) => _mapTagViews(rows, usageCount));
  }

  @override
  Future<List<TagView>> listTags() async {
    final usageCount = _usageCountExpression();
    return _mapTagViews(await _tagSelect(usageCount).get(), usageCount);
  }

  @override
  Future<void> insertTag({required String id, required String name}) {
    return _db.into(_db.tags).insert(TagsCompanion.insert(id: id, name: name));
  }

  @override
  Future<void> renameTag({required String id, required String name}) {
    return (_db.update(_db.tags)..where((table) => table.id.equals(id))).write(
      TagsCompanion(name: Value(name), updatedAt: Value(DateTime.now())),
    );
  }

  @override
  Future<void> mergeTags({required String sourceId, required String targetId}) {
    return _db.transaction(() async {
      final sourceRows =
          await (_db.select(_db.transactionTags)
            ..where((table) => table.tagId.equals(sourceId))).get();
      if (sourceRows.isNotEmpty) {
        final targetTransactions =
            (await (_db.select(_db.transactionTags)
                  ..where((table) => table.tagId.equals(targetId))).get())
                .map((row) => row.transactionId)
                .toSet();
        await _db.batch((batch) {
          for (final row in sourceRows) {
            if (targetTransactions.contains(row.transactionId)) continue;
            batch.insert(
              _db.transactionTags,
              TransactionTagsCompanion.insert(
                transactionId: row.transactionId,
                tagId: targetId,
              ),
            );
          }
        });
        await (_db.delete(_db.transactionTags)
          ..where((table) => table.tagId.equals(sourceId))).go();
      }
      await _deleteTagRow(sourceId);
    });
  }

  @override
  Future<void> deleteTag(String id) {
    return _db.transaction(() async {
      await (_db.delete(_db.transactionTags)
        ..where((table) => table.tagId.equals(id))).go();
      await _deleteTagRow(id);
    });
  }

  @override
  Future<void> moveTag({required String id, required int delta}) {
    if (delta != -1 && delta != 1) {
      throw ArgumentError.value(delta, 'delta', 'Expected -1 or 1.');
    }
    return _db.transaction(() async {
      final tags = await listTags();
      final index = tags.indexWhere((tag) => tag.id == id);
      if (index < 0) return;
      final target = index + delta;
      if (target < 0 || target >= tags.length) return;
      final orderedIds = [for (final tag in tags) tag.id];
      final moved = orderedIds.removeAt(index);
      orderedIds.insert(target, moved);
      await _db.batch((batch) {
        for (var position = 0; position < orderedIds.length; position++) {
          batch.update(
            _db.tags,
            TagsCompanion(sortOrder: Value(position)),
            where: (table) => table.id.equals(orderedIds[position]),
          );
        }
      });
    });
  }

  @override
  Future<Set<String>> transactionTagIds(String transactionId) async {
    final rootId = await _rootTransactionId(transactionId);
    if (rootId == null) return const {};
    final rows =
        await (_db.select(_db.transactionTags)
          ..where((table) => table.transactionId.equals(rootId))).get();
    return rows.map((row) => row.tagId).toSet();
  }

  @override
  Stream<Set<String>> watchTransactionTagIds(String transactionId) async* {
    yield await transactionTagIds(transactionId);
    await for (final _ in _db.tableUpdates(
      TableUpdateQuery.onAllTables([
        _db.transactions,
        _db.tags,
        _db.transactionTags,
      ]),
    )) {
      yield await transactionTagIds(transactionId);
    }
  }

  @override
  Future<void> replaceTransactionTags({
    required String transactionId,
    required Set<String> tagIds,
  }) {
    return _db.transaction(() async {
      await (_db.delete(_db.transactionTags)
        ..where((table) => table.transactionId.equals(transactionId))).go();
      if (tagIds.isEmpty) return;
      final validIds =
          await (_db.selectOnly(_db.tags)
                ..addColumns([_db.tags.id])
                ..where(_db.tags.id.isIn(tagIds)))
              .get();
      await _db.batch((batch) {
        for (final row in validIds) {
          final tagId = row.read(_db.tags.id);
          if (tagId == null) continue;
          batch.insert(
            _db.transactionTags,
            TransactionTagsCompanion.insert(
              transactionId: transactionId,
              tagId: tagId,
            ),
          );
        }
      });
    });
  }

  Expression<int> _usageCountExpression() {
    return subqueryExpression<int>(
      _db.selectOnly(_db.transactionTags)
        ..addColumns([countAll()])
        ..where(_db.transactionTags.tagId.equalsExp(_db.tags.id)),
    );
  }

  JoinedSelectStatement<$TagsTable, TagRow> _tagSelect(
    Expression<int> usageCount,
  ) {
    final select =
        _db.selectOnly(_db.tags)
          ..addColumns([
            _db.tags.id,
            _db.tags.name,
            _db.tags.sortOrder,
            usageCount,
          ])
          ..orderBy([
            OrderingTerm.asc(_db.tags.sortOrder),
            OrderingTerm.asc(_db.tags.name),
          ]);
    return select;
  }

  List<TagView> _mapTagViews(
    List<TypedResult> rows,
    Expression<int> usageCount,
  ) {
    return [
      for (final row in rows)
        TagView(
          id: row.read(_db.tags.id)!,
          name: row.read(_db.tags.name)!,
          sortOrder: row.read(_db.tags.sortOrder) ?? 0,
          usageCount: row.read(usageCount) ?? 0,
        ),
    ];
  }

  Future<void> _deleteTagRow(String id) {
    return (_db.delete(_db.tags)..where((table) => table.id.equals(id))).go();
  }

  /// 标签只挂在顶层交易上；子交易沿 `parent_transaction_id` 找到所属顶层。
  Future<String?> _rootTransactionId(String transactionId) async {
    final row =
        await (_db.selectOnly(_db.transactions)
              ..addColumns([_db.transactions.parentTransactionId])
              ..where(_db.transactions.id.equals(transactionId)))
            .getSingleOrNull();
    if (row == null) return null;
    final parentId = row.read<String>(_db.transactions.parentTransactionId);
    return parentId ?? transactionId;
  }
}
