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

/// Defines which persisted representation a transaction filter matches.
sealed class TransactionMatch {
  const TransactionMatch({this.categoryAccountIds, this.settlementAccountIds});

  /// `null` means this dimension is not filtered; an empty set matches none.
  final Set<String>? categoryAccountIds;

  /// `null` means this dimension is not filtered; an empty set matches none.
  final Set<String>? settlementAccountIds;
}

/// Matches user-visible transaction facts stored in `transaction_lines`.
final class TransactionFactMatch extends TransactionMatch {
  const TransactionFactMatch({
    super.categoryAccountIds,
    super.settlementAccountIds,
  });
}

/// Matches actual ledger impact stored in `entries`.
final class TransactionImpactMatch extends TransactionMatch {
  const TransactionImpactMatch({
    super.categoryAccountIds,
    super.settlementAccountIds,
  });
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
    this.match = const TransactionFactMatch(),
    this.occurredFrom,
    this.occurredUntil,
    this.topLevelOnly = true,
    this.limit = 50,
    this.offset = 0,
    this.before,
    this.scope = TransactionScopeFilter.assetLiability,
    this.tagIds,
    this.untaggedOnly = false,
  }) : assert(limit != null || offset == 0),
       assert(before == null || offset == 0),
       assert(!untaggedOnly || tagIds == null);

  final TransactionMatch match;

  /// 标签维度：`null` 表示不筛选，空集合表示维度已启用但无有效标签；
  /// 匹配语义为任一命中（OR），子交易按所属顶层交易的标签继承命中。
  final Set<String>? tagIds;

  /// 只匹配未携带任何标签的交易；与 [tagIds] 互斥。
  final bool untaggedOnly;

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
/// [match] 决定两个账户维度匹配交易分项事实还是账务影响分录；两个维度
/// 各自独立匹配后取交集。`null` 表示该维度缺省，空集合表示该维度无可匹配项，
/// 结果恒为空。标签维度按事件级语义匹配：
/// 标签挂在顶层交易上，子交易经 `parent_transaction_id` 继承命中。
class TransactionPageQuery {
  const TransactionPageQuery({
    this.match = const TransactionFactMatch(),
    this.occurredFrom,
    this.occurredUntil,
    this.topLevelOnly = true,
    this.limit,
    this.offset = 0,
    this.before,
    this.scope = TransactionScopeFilter.assetLiability,
    this.tagIds,
    this.untaggedOnly = false,
  }) : assert(!untaggedOnly || tagIds == null);

  final TransactionMatch match;
  final Set<String>? tagIds;
  final bool untaggedOnly;
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
/// 分类与账户优先按顶层交易的分类/结算分项事实匹配，同时纳入历史分录作为
/// 旧数据兼容来源；不匹配子交易。时间按顶层交易的交易时间匹配，
/// `occurredUntil` 为排他端点。
class TransactionCleanupQuery {
  const TransactionCleanupQuery({
    this.transactionIds,
    this.categoryIds,
    this.accountIds,
    this.occurredFrom,
    this.occurredUntil,
  });

  /// 显式指定待处理的顶层交易 ID；与其它条件一起使用时取交集。
  final Set<String>? transactionIds;
  final Set<String>? categoryIds;
  final Set<String>? accountIds;
  final DateTime? occurredFrom;
  final DateTime? occurredUntil;
}
