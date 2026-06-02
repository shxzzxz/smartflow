import '../../core/result/result.dart';

/// application 用例级原子边界抽象。
///
/// 用例编排多步写操作时通过 [run] 包住关键路径；infrastructure 层用底层
/// 数据库事务实现，让回调内部的写入要么全部生效，要么统一回滚。
abstract interface class TransactionRunner {
  /// 在事务内执行 [body]。
  ///
  /// 契约：
  /// - [Success] 提交事务。
  /// - 最终返回 [FailureResult] 时回滚事务，并向调用方返回同一个 failure。
  /// - 未捕获异常由底层事务机制回滚后继续抛出。
  /// - 嵌套 [run] 是过渡期允许的实现细节；外层是否回滚取决于外层
  ///   [body] 的最终结果。
  Future<Result<T>> run<T>(Future<Result<T>> Function() body);

  /// 在事务内执行返回普通值的 [body]。
  ///
  /// 契约：
  /// - [body] 正常返回时提交事务。
  /// - [body] 抛出任何异常时由底层事务机制回滚，并原样继续抛出。
  Future<T> runValue<T>(Future<T> Function() body);
}
