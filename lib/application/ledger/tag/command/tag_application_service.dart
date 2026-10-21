import 'package:smartflow/core/id/id_generator.dart';

import '../../../shared/transaction_runner.dart';
import '../query/port/tag_repository.dart';
import '../query/tag_read_models.dart';

/// 标签词表的应用服务：创建（含查重复用）、重命名、合并、迁移、排序与删除。
///
/// 词表内名称唯一（去除首尾空白后精确匹配）；重命名撞名直接拒绝。
/// 单笔交易的标签替换仍由交易写入编排处理；词表合并、迁移与批量删除
/// 由本服务建立外层事务。
class TagApplicationService {
  const TagApplicationService({
    required TransactionTagRepository repository,
    required IdGenerator idGenerator,
    required TransactionRunner transactionRunner,
  }) : _repository = repository,
       _idGenerator = idGenerator,
       _transactionRunner = transactionRunner;

  final TransactionTagRepository _repository;
  final IdGenerator _idGenerator;
  final TransactionRunner _transactionRunner;

  Stream<List<TagView>> watchTags() => _repository.watchTags();

  Future<List<TagView>> listTags() => _repository.listTags();

  Future<Set<String>> transactionTagIds(String transactionId) =>
      _repository.transactionTagIds(transactionId);

  Stream<Set<String>> watchTransactionTagIds(String transactionId) =>
      _repository.watchTransactionTagIds(transactionId);

  /// 创建标签并返回其 ID；词表内已有同名标签时复用既有标签。
  Future<String> createTag(String name) async {
    final trimmed = _normalizeName(name);
    final tags = await _repository.listTags();
    for (final tag in tags) {
      if (tag.name == trimmed) return tag.id;
    }
    final id = _idGenerator.newId();
    await _repository.insertTag(id: id, name: trimmed);
    return id;
  }

  Future<void> renameTag({required String id, required String name}) async {
    final trimmed = _normalizeName(name);
    final tags = await _repository.listTags();
    for (final tag in tags) {
      if (tag.id != id && tag.name == trimmed) {
        throw StateError('A tag named "$trimmed" already exists.');
      }
    }
    await _repository.renameTag(id: id, name: trimmed);
  }

  Future<void> mergeTags({
    required Set<String> sourceIds,
    required String targetId,
  }) async {
    final orderedSourceIds = await _validateReferenceOperation(
      sourceIds: sourceIds,
      targetId: targetId,
    );
    await _transactionRunner.run(() async {
      for (final sourceId in orderedSourceIds) {
        await _repository.mergeTags(sourceId: sourceId, targetId: targetId);
      }
    });
  }

  /// 将源标签的交易引用改指向目标标签，但保留源标签。
  Future<void> migrateTags({
    required Set<String> sourceIds,
    required String targetId,
  }) async {
    final orderedSourceIds = await _validateReferenceOperation(
      sourceIds: sourceIds,
      targetId: targetId,
    );
    await _transactionRunner.run(() async {
      for (final sourceId in orderedSourceIds) {
        await _repository.migrateTag(sourceId: sourceId, targetId: targetId);
      }
    });
  }

  Future<void> deleteTag(String id) => deleteTags({id});

  Future<void> deleteTags(Set<String> ids) async {
    if (ids.isEmpty) return;
    await _transactionRunner.run(() async {
      for (final id in ids) {
        await _repository.deleteTag(id);
      }
    });
  }

  Future<void> moveTag({required String id, required int delta}) =>
      _repository.moveTag(id: id, delta: delta);

  String _normalizeName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Tag name cannot be empty.');
    }
    return trimmed;
  }

  Future<List<String>> _validateReferenceOperation({
    required Set<String> sourceIds,
    required String targetId,
  }) async {
    if (sourceIds.isEmpty) {
      throw ArgumentError.value(sourceIds, 'sourceIds', 'Cannot be empty.');
    }
    if (sourceIds.contains(targetId)) {
      throw ArgumentError.value(
        targetId,
        'targetId',
        'Target must be outside the source selection.',
      );
    }
    final tags = await _repository.listTags();
    final knownIds = tags.map((tag) => tag.id).toSet();
    if (!knownIds.contains(targetId) || !sourceIds.every(knownIds.contains)) {
      throw ArgumentError('Source and target tags must exist.');
    }
    return [
      for (final tag in tags)
        if (sourceIds.contains(tag.id)) tag.id,
    ];
  }
}
