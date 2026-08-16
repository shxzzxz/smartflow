import 'package:smartflow/application/ledger/tag/query/tag_read_models.dart';
import 'package:smartflow/application/ledger/tag/query/port/tag_repository.dart';

/// 测试用内存标签仓储：记录写入调用，供 writer 事务性断言使用。
class FakeTransactionTagRepository implements TransactionTagRepository {
  final Map<String, TagView> _tagsById = {};
  final Map<String, Set<String>> _tagIdsByTransaction = {};
  final List<({String transactionId, Set<String> tagIds})> replaceCalls = [];

  @override
  Future<List<TagView>> listTags() async {
    final tags =
        _tagsById.values.toList()..sort((a, b) {
          final byOrder = a.sortOrder.compareTo(b.sortOrder);
          return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
        });
    return tags;
  }

  @override
  Stream<List<TagView>> watchTags() async* {
    yield await listTags();
  }

  @override
  Future<void> insertTag({required String id, required String name}) async {
    _tagsById[id] = TagView(
      id: id,
      name: name,
      sortOrder: _tagsById.length,
      usageCount: 0,
    );
  }

  @override
  Future<void> renameTag({required String id, required String name}) async {
    final tag = _tagsById[id];
    if (tag == null) return;
    _tagsById[id] = TagView(
      id: id,
      name: name,
      sortOrder: tag.sortOrder,
      usageCount: tag.usageCount,
    );
  }

  @override
  Future<void> mergeTags({
    required String sourceId,
    required String targetId,
  }) async {
    final sourceTransactions =
        _tagIdsByTransaction.entries
            .where((entry) => entry.value.contains(sourceId))
            .map((entry) => entry.key)
            .toList();
    for (final transactionId in sourceTransactions) {
      _tagIdsByTransaction[transactionId]!
        ..remove(sourceId)
        ..add(targetId);
    }
    _tagsById.remove(sourceId);
  }

  @override
  Future<void> deleteTag(String id) async {
    _tagsById.remove(id);
    for (final tagIds in _tagIdsByTransaction.values) {
      tagIds.remove(id);
    }
  }

  @override
  Future<void> moveTag({required String id, required int delta}) async {}

  @override
  Future<Set<String>> transactionTagIds(String transactionId) async {
    return _tagIdsByTransaction[transactionId] ?? const {};
  }

  @override
  Stream<Set<String>> watchTransactionTagIds(String transactionId) async* {
    yield await transactionTagIds(transactionId);
  }

  @override
  Future<void> replaceTransactionTags({
    required String transactionId,
    required Set<String> tagIds,
  }) async {
    replaceCalls.add((transactionId: transactionId, tagIds: tagIds));
    _tagIdsByTransaction[transactionId] = {...tagIds};
  }
}
