import 'tag_read_models.dart';

/// 标签词表与交易-标签关联的存储端口。
///
/// 标签是交易的描述性事实而非账务真相，因此该端口属于应用层，
/// 不进入账务核心的领域端口。关联行只允许出现在顶层交易上，
/// 由调用方保证；存储端只负责过滤已不存在的标签 ID，防止悬挂引用。
abstract interface class TransactionTagRepository {
  /// 按词表排序 `(sort_order, name)` 监听全部标签。
  Stream<List<TagView>> watchTags();

  Future<List<TagView>> listTags();

  Future<void> insertTag({required String id, required String name});

  Future<void> renameTag({required String id, required String name});

  /// 把 source 标签的全部交易引用改指向 target，然后删除 source。
  Future<void> mergeTags({
    required String sourceId,
    required String targetId,
  });

  /// 删除标签及其全部交易引用。
  Future<void> deleteTag(String id);

  /// 在词表内移动标签一位；[delta] 取 -1 或 1。
  Future<void> moveTag({required String id, required int delta});

  /// 顶层交易当前携带的标签 ID 集合；子交易返回所属顶层交易的标签。
  Future<Set<String>> transactionTagIds(String transactionId);

  Stream<Set<String>> watchTransactionTagIds(String transactionId);

  /// 用 [tagIds] 整体替换某笔交易的标签关联；空集合表示清空。
  Future<void> replaceTransactionTags({
    required String transactionId,
    required Set<String> tagIds,
  });
}
