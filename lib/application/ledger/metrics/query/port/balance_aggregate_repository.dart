import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

import '../../../transaction/query/transaction_scope.dart';

/// 时间窗口(half-open: `[from, until)`)。`from` 为 null 表示无下界,`until` 为 null 表示无上界。
class DateTimeWindow {
  const DateTimeWindow({this.from, this.until});
  final DateTime? from;
  final DateTime? until;
}

/// 余额累计聚合(entries × account × transaction)。
///
/// 此场景按 account_type 分桶累计,JOIN account 是该领域本分,不在「列表去 account」
/// 的约束之内。
abstract interface class BalanceAggregateRepository {
  /// 按账户类型分桶累计 entries 的余额变化(应用 [TransactionScopeFilter] 口径)。
  Future<Map<AccountType, int>> aggregateByAccountType({
    required Set<AccountType> accountTypes,
    required TransactionScopeFilter scope,
    DateTimeWindow window = const DateTimeWindow(),
  });

  /// 多窗口批量版,N 个 cutoff 对应 N 个聚合结果。
  /// 用于净资产趋势等「多时间点截止累计」的场景。
  Future<List<Map<AccountType, int>>> aggregateByAccountTypeAtCutoffs({
    required Set<AccountType> accountTypes,
    required TransactionScopeFilter scope,
    required List<DateTimeWindow> windows,
  });

  /// 按 `(occurred_at as date, account_type)` 双维分组累计。
  /// 用于每日现金流摘要等「按日分桶」的场景。
  ///
  /// 返回 `Map<日期, Map<账户类型, 余额变化 minor>>`,日期按 [DateTime] 标准化为
  /// 当日 0 点(无时区偏移)。
  Future<Map<DateTime, Map<AccountType, int>>> aggregateByAccountTypeByDay({
    required Set<AccountType> accountTypes,
    required TransactionScopeFilter scope,
    DateTimeWindow window = const DateTimeWindow(),
  });

  /// 监听底层数据变化(transaction / entries / account 任一表更新触发)。
  ///
  /// 立即发射一次,随后每次相关表更新再次发射。供上层 service 用 `asyncMap` 编排
  /// 多个 `aggregateXxx` 调用并对外暴露 Stream。
  Stream<void> watchChanges();
}
