import '../entities/transaction.dart';
import '../enums/accounting_enums.dart';
import '../queries/transaction_queries.dart';

/// 子树聚合结果:对一个 root 下满足条件的子交易统计的 (sum, count)。
class TransactionChildAggregate {
  const TransactionChildAggregate({required this.sumMinor, required this.count});

  final int sumMinor;
  final int count;

  static const TransactionChildAggregate empty = TransactionChildAggregate(
    sumMinor: 0,
    count: 0,
  );
}

/// 交易表(transactions)的纯读能力。
///
/// 接口面向会计概念,业务字面量(具体的 `BusinessPurpose` / `BusinessState` 值)
/// 通过参数 Set 传入,repo 不知道这些参数对应的业务流程语义。
abstract interface class TransactionReadRepository {
  Future<Transaction?> findById(int id);

  Future<List<Transaction>> findByIds(Set<int> ids);

  /// 监听一页交易行。响应式跟随 transactions 表变更触发。
  Stream<List<Transaction>> watchPage(TransactionListQuery query);

  /// 取以 `parentId` 为直接父交易的子交易列表。
  /// `states` 为 null 表示不过滤 state。
  Future<List<Transaction>> findChildren({
    required int parentId,
    Set<BusinessState>? states,
  });

  /// 取以 `rootId` 为根的子树中的全部行,可选排除某 id。
  /// `excludeStateMutation` 排除指定 (state, mutationKind) 组合的行(用于
  /// 「排除当前激活的 original」这种 history view 语义)。
  Future<List<Transaction>> findRootDescendants({
    required int rootId,
    int? excludeId,
    ({BusinessState state, MutationKind mutationKind})? excludeStateMutation,
  });

  /// 按 rootId 维度,对子交易里 (purpose ∈ purposes ∧ state ∈ states) 的行
  /// 求 primary_amount 和 + count。
  ///
  /// 业务字面量(refund / receipt / close 等)通过 `purposes` 集合传入,
  /// repo 仅按值做 IN 过滤,不知道这些 purpose 对应的业务流程。
  Future<Map<int, TransactionChildAggregate>> aggregateChildren({
    required Set<int> rootIds,
    required Set<BusinessPurpose> purposes,
    required Set<BusinessState> states,
  });

  /// 按 rootId 维度,对子交易关联的 transaction_details 中
  /// (detail.type ∈ detailTypes ∧ child.state ∈ states) 的行,按 type 分桶求和。
  Future<Map<int, Map<TransactionDetailType, int>>> aggregateChildDetailAmounts({
    required Set<int> rootIds,
    required Set<TransactionDetailType> detailTypes,
    required Set<BusinessState> states,
  });
}
