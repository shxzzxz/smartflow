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
}
