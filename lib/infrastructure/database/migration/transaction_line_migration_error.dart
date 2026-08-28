enum TransactionLineMigrationFailureReason {
  /// 交易的分录形态不符合该 business_purpose 的既有过账规则,无法推断角色账户。
  unexpectedEntryShape,

  /// 报销垫付缺少支出分类,分项无法补齐。
  missingReimbursementExpenseCategory,

  /// 分录引用了 accounts 表中不存在的账户。
  unknownAccount,

  /// 回填后的分项重新过账,结果与库中现存分录不一致。
  postingReplayMismatch,
}

/// v29 交易分项迁移中的不可恢复不一致。
///
/// 抛出时升级事务整体回滚。稳定的原因码与交易标识让日志和支持诊断无需解析
/// 自由文本即可定位问题交易。
final class TransactionLineMigrationError implements Exception {
  const TransactionLineMigrationError({
    required this.transactionId,
    required this.reason,
    this.businessPurpose,
    this.detail,
  });

  final String transactionId;
  final TransactionLineMigrationFailureReason reason;
  final String? businessPurpose;
  final String? detail;

  @override
  String toString() {
    return 'TransactionLineMigrationError('
        'reason=${reason.name}, '
        'transactionId=$transactionId, '
        'businessPurpose=$businessPurpose, '
        'detail=$detail)';
  }
}
