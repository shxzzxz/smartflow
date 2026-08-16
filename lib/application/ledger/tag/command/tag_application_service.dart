import 'package:smartflow/core/id/id_generator.dart';

import '../query/port/tag_repository.dart';
import '../query/tag_read_models.dart';

/// 标签词表的应用服务：创建（含查重复用）、重命名、合并、排序与删除。
///
/// 词表内名称唯一（去除首尾空白后精确匹配）；重命名撞名直接拒绝。
/// 标签与交易关联的写入不走本服务，由交易写入编排统一保证事务性。
class TagApplicationService {
  const TagApplicationService({
    required TransactionTagRepository repository,
    required IdGenerator idGenerator,
  }) : _repository = repository,
       _idGenerator = idGenerator;

  final TransactionTagRepository _repository;
  final IdGenerator _idGenerator;

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
    required String sourceId,
    required String targetId,
  }) async {
    if (sourceId == targetId) {
      throw ArgumentError.value(
        sourceId,
        'sourceId',
        'Cannot merge a tag into itself.',
      );
    }
    await _repository.mergeTags(sourceId: sourceId, targetId: targetId);
  }

  Future<void> deleteTag(String id) => _repository.deleteTag(id);

  Future<void> moveTag({required String id, required int delta}) =>
      _repository.moveTag(id: id, delta: delta);

  String _normalizeName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Tag name cannot be empty.');
    }
    return trimmed;
  }
}
