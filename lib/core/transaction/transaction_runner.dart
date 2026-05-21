import '../result/result.dart';

/// 跨表 / 跨步骤的原子边界抽象。
///
/// service 编排多步操作时通过 [run] 包住关键路径；data 层用底层数据库事务实现，
/// 让回调内部的所有写入要么全部生效，要么因失败 / 抛错统一回滚。
abstract interface class TransactionRunner {
  /// 在事务内执行 [body]，失败结果会触发回滚后再向上返回。
  Future<Result<T>> run<T>(Future<Result<T>> Function() body);
}
