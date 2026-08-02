import 'transaction_scope.dart';

class TransactionListQuery {
  const TransactionListQuery({
    this.accountId,
    this.accountIds,
    this.occurredFrom,
    this.occurredUntil,
    this.topLevelOnly = true,
    this.limit = 50,
    this.offset = 0,
    this.before,
    this.scope = TransactionScopeFilter.assetLiability,
  }) : assert(accountId == null || accountIds == null),
       assert(limit != null || offset == 0),
       assert(before == null || offset == 0);

  final String? accountId;
  final Set<String>? accountIds;
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
