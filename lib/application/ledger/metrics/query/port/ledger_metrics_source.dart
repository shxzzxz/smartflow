import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/core/time/month_key.dart';

import '../../../transaction/query/transaction_scope.dart';

/// 时间窗口(half-open: `[from, until)`)。`from` 为 null 表示无下界,`until` 为 null 表示无上界。
class DateTimeWindow {
  const DateTimeWindow({this.from, this.until});
  final DateTime? from;
  final DateTime? until;
}

class AccountAggregate {
  const AccountAggregate({
    required this.accountId,
    required this.accountType,
    required this.amountMinor,
  });

  final String accountId;
  final AccountType accountType;
  final int amountMinor;

  @override
  bool operator ==(Object other) {
    return other is AccountAggregate &&
        other.accountId == accountId &&
        other.accountType == accountType &&
        other.amountMinor == amountMinor;
  }

  @override
  int get hashCode => Object.hash(accountId, accountType, amountMinor);
}

/// 按标签聚合的余额变化事实。`tagId` 为 null 表示未打标签的交易净额。
class TagAggregate {
  const TagAggregate({
    required this.tagId,
    required this.accountType,
    required this.amountMinor,
  });

  final String? tagId;
  final AccountType accountType;
  final int amountMinor;

  @override
  bool operator ==(Object other) =>
      other is TagAggregate &&
      other.tagId == tagId &&
      other.accountType == accountType &&
      other.amountMinor == amountMinor;

  @override
  int get hashCode => Object.hash(tagId, accountType, amountMinor);
}

/// 账务指标事实源(entries × account × transaction)。
///
/// 此场景按 account_type 分桶累计,JOIN account 是该领域本分,不在「列表去 account」
/// 的约束之内。
abstract interface class LedgerMetricsSource {
  /// 按账户类型分桶累计 entries 的余额变化(应用 [TransactionScopeFilter] 口径)。
  Future<Map<AccountType, int>> aggregateByAccountType({
    required Set<AccountType> accountTypes,
    required TransactionScopeFilter scope,
    DateTimeWindow window = const DateTimeWindow(),
  });

  /// 按实际分录账户（物理分类粒度）累计余额变化；归档账户不参与统计。
  Future<List<AccountAggregate>> aggregateByAccount({
    required Set<AccountType> accountTypes,
    required TransactionScopeFilter scope,
    DateTimeWindow window = const DateTimeWindow(),
  });

  /// 按 `(标签, account_type)` 聚合余额变化（应用 [TransactionScopeFilter] 口径）。
  ///
  /// 标签挂在顶层交易上，子交易经所属顶层继承；`tagId` 为 null 的聚合行
  /// 表示未打标签的交易。同一笔交易携带多个标签时在每个标签桶各计一次，
  /// 这是标签统计「命中该标签的交易净额」的既定口径。
  Future<List<TagAggregate>> aggregateByTag({
    required Set<AccountType> accountTypes,
    required TransactionScopeFilter scope,
    DateTimeWindow window = const DateTimeWindow(),
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

  /// 单次扫描有界时间窗口，并按 `(本地月份, account_type)` 累计。
  ///
  /// [window] 必须同时包含 from 与 until；实现按本地月边界在 SQL 中分桶。
  Future<Map<MonthKey, Map<AccountType, int>>> aggregateByAccountTypeByMonth({
    required Set<AccountType> accountTypes,
    required TransactionScopeFilter scope,
    required DateTimeWindow window,
  });

  /// 监听底层数据变化(transaction / entries / account 任一表更新触发)。
  ///
  /// 立即发射一次,随后每次相关表更新再次发射。供上层 service 用 `asyncMap` 编排
  /// 多个 `aggregateXxx` 调用并对外暴露 Stream。
  Stream<void> watchChanges();
}
