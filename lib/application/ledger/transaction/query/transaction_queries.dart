import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

import 'transaction_scope.dart';

enum TransactionHierarchyFilter { topLevel, child }

/// 按分类查找交易时限定顶层或子交易。
class CategoryTransactionQuery {
  const CategoryTransactionQuery({
    required this.categoryId,
    this.hierarchy = TransactionHierarchyFilter.topLevel,
  });

  final String categoryId;
  final TransactionHierarchyFilter hierarchy;
}

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

/// 将语义分类选择解析为当前账户快照中的物理分类账户 ID。
Set<String> resolveCategoryAccountIds(
  Iterable<CategorySelection> selections,
  Map<String, Account> accountsById,
) {
  final resolved = <String>{};
  for (final selection in selections) {
    final category = accountsById[selection.id];
    if (category == null ||
        (category.type != AccountType.income &&
            category.type != AccountType.expense) ||
        category.isArchived) {
      continue;
    }
    resolved.add(category.id);
    if (selection.matchOwnOnly || category.parentId != null) continue;
    for (final account in accountsById.values) {
      if (account.type == category.type &&
          !account.isArchived &&
          account.parentId == category.id) {
        resolved.add(account.id);
      }
    }
  }
  return resolved;
}

class TransactionListQuery {
  const TransactionListQuery({
    this.categoryAccountIds,
    this.settlementAccountIds,
    this.occurredFrom,
    this.occurredUntil,
    this.topLevelOnly = true,
    this.limit = 50,
    this.offset = 0,
    this.before,
    this.scope = TransactionScopeFilter.assetLiability,
  }) : assert(limit != null || offset == 0),
       assert(before == null || offset == 0);

  /// `null` 表示不筛选，空集合表示筛选维度已启用但无有效物理账户。
  final Set<String>? categoryAccountIds;

  /// `null` 表示不筛选，空集合表示筛选维度已启用但无有效物理账户。
  final Set<String>? settlementAccountIds;

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
