/// application 用例级原子边界抽象。
///
/// 用例编排多步写操作时通过 [run] 包住关键路径；infrastructure 层用底层
/// 数据库事务实现，让回调内部的写入要么全部生效，要么统一回滚。
abstract interface class TransactionRunner {
  /// 在事务内执行返回普通值的 [body]。
  ///
  /// 契约：
  /// - [body] 正常返回时提交事务。
  /// - [body] 抛出任何异常时由底层事务机制回滚，并原样继续抛出。
  Future<T> run<T>(Future<T> Function() body);
}
