import 'transaction_scope.dart';

/// 用户选择的单个活跃分类及其匹配范围。
///
/// 这是分类筛选这一维度的语义，不是可与 [TransactionListQuery]
/// 其他条件自由组合的额外开关。“未细分”统计项选择一级分类自身，
/// 其他分类选择则按其活跃二级分类展开。
class CategorySelection {
  const CategorySelection.withDescendants(this.id) : matchOwnOnly = false;

  const CategorySelection.ownOnly(this.id) : matchOwnOnly = true;

  final String id;
  final bool matchOwnOnly;

  @override
  bool operator ==(Object other) =>
      other is CategorySelection &&
      other.id == id &&
      other.matchOwnOnly == matchOwnOnly;

  @override
  int get hashCode => Object.hash(id, matchOwnOnly);
}

class TransactionListQuery {
  const TransactionListQuery({
    this.category,
    this.settlementAccountId,
    this.occurredFrom,
    this.occurredUntil,
    this.topLevelOnly = true,
    this.limit = 50,
    this.offset = 0,
    this.before,
    this.scope = TransactionScopeFilter.assetLiability,
  }) : assert(limit != null || offset == 0),
       assert(before == null || offset == 0);

  /// 用户选择的活跃分类。一级分类在查询层展开为自身与全部二级分类，
  /// 二级分类展开为自身；与结算账户维度同时存在时取交集。
  final CategorySelection? category;

  /// 用户选择的结算账户，不表达"任意账户 ID"。
  final String? settlementAccountId;

  final DateTime? occurredFrom;
  final DateTime? occurredUntil;
  final bool topLevelOnly;
  final int? limit;
  final int offset;
  final TransactionListCursor? before;
  final TransactionScopeFilter scope;
}

/// 仓储层翻页查询。分类树已由查询层展开为物理分类 ID 集合，仓储不理解分类树。
///
/// 两个账户维度各自独立匹配分录后取交集；`null` 表示该维度缺省，
/// 空集合表示该维度无可匹配项，结果恒为空。
class TransactionPageQuery {
  const TransactionPageQuery({
    this.categoryAccountIds,
    this.settlementAccountIds,
    this.occurredFrom,
    this.occurredUntil,
    this.topLevelOnly = true,
    this.limit,
    this.offset = 0,
    this.before,
    this.scope = TransactionScopeFilter.assetLiability,
  });

  final Set<String>? categoryAccountIds;
  final Set<String>? settlementAccountIds;
  final DateTime? occurredFrom;
  final DateTime? occurredUntil;
  final bool topLevelOnly;
  final int? limit;
  final int offset;
  final TransactionListCursor? before;
  final TransactionScopeFilter scope;
}

/// 按交易列表稳定排序 `(occurredAt DESC, id DESC)` 翻页时的排他游标。
class TransactionListCursor {
  const TransactionListCursor({required this.occurredAt, required this.id});

  final DateTime occurredAt;
  final String id;
}

class CashflowSummaryQuery {
  const CashflowSummaryQuery({
    required this.occurredFrom,
    required this.occurredUntil,
  });

  final DateTime occurredFrom;
  final DateTime occurredUntil;
}

/// 数据清理的条件口径，匹配单位是交易组（顶层交易）。
///
/// 条件类型之间取交集，集合内取并集；`null` 表示该条件不限，集合不允许为空。
/// 分类与账户都按顶层交易分录触达的账户匹配；时间按顶层交易的交易时间匹配，
/// `occurredUntil` 为排他端点。
class TransactionCleanupQuery {
  const TransactionCleanupQuery({
    this.categoryIds,
    this.accountIds,
    this.occurredFrom,
    this.occurredUntil,
  });

  final Set<String>? categoryIds;
  final Set<String>? accountIds;
  final DateTime? occurredFrom;
  final DateTime? occurredUntil;
}
