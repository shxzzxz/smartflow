import '../counterparty_read_models.dart';

/// 对手方词表的存储端口。
///
/// 对手方是交易上的单值外部主体引用，不是账务真相。引用一致性由应用层
/// 维护，不使用数据库外键。
abstract interface class CounterpartyRepository {
  /// 按名称稳定排序监听全部对手方。
  Stream<List<CounterpartyView>> watchCounterparties();

  Future<List<CounterpartyView>> listCounterparties();

  Future<Map<String, CounterpartyView>> findByIds(Set<String> ids);

  Future<void> insertCounterparty({required String id, required String name});

  Future<void> renameCounterparty({required String id, required String name});

  /// 将 [sourceIds] 的交易引用整体改指向 [targetId]。
  Future<void> reassignTransactionReferences({
    required Set<String> sourceIds,
    required String targetId,
  });

  /// 清空所有交易上的对手方引用，供 application 用例在删除前调用。
  Future<void> clearTransactionReferences(String counterpartyId);

  /// 物理删除词表记录；调用方必须先处理交易引用。
  Future<void> deleteCounterparty(String id);
}
