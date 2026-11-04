/// 普通交易组业务活动的稳定类型标识。
const String ledgerTransactionGroupActivityType = 'ledger.transaction_group';

/// 业务活动的稳定身份。
///
/// owner 型事项使用 `(ownerType, ownerId)`，无 owner 的普通交易组使用
/// [ledgerTransactionGroupActivityType] 和顶层交易组 ID。
final class BusinessActivityKey {
  const BusinessActivityKey({required this.type, required this.id})
    : assert(type != ''),
      assert(id != '');

  const BusinessActivityKey.transactionGroup(String id)
    : this(type: ledgerTransactionGroupActivityType, id: id);

  final String type;
  final String id;

  int compareTo(BusinessActivityKey other) {
    final typeOrder = type.compareTo(other.type);
    return typeOrder != 0 ? typeOrder : id.compareTo(other.id);
  }

  @override
  bool operator ==(Object other) {
    return other is BusinessActivityKey && other.type == type && other.id == id;
  }

  @override
  int get hashCode => Object.hash(type, id);
}

/// 业务活动视图的排他游标；排序方向为 `(activityAt DESC, activityKey DESC)`。
final class BusinessActivityCursor {
  const BusinessActivityCursor({
    required this.activityAt,
    required this.activityKey,
  });

  /// 业务活动自身的展示与排序时间，不等同于展示交易的交易时间。
  final DateTime activityAt;
  final BusinessActivityKey activityKey;
}

/// 业务活动来源统一使用的分页与筛选条件。
///
/// `occurredUntil` 是排他端点。各来源必须在执行 `LIMIT` 前完成全部筛选和
/// 游标判断；公共查询层不补做业务过滤。集合为 `null` 表示不筛选，空集合
/// 表示条件已启用但没有可匹配项。
final class BusinessActivityPageQuery {
  BusinessActivityPageQuery({
    required this.occurredFrom,
    required this.occurredUntil,
    this.before,
    this.limit = 20,
    Set<String>? activityTypes,
    Set<String>? categoryAccountIds,
    Set<String>? settlementAccountIds,
    Set<String>? tagIds,
    this.untaggedOnly = false,
    this.counterpartyId,
  }) : activityTypes = _immutableSet(activityTypes),
       categoryAccountIds = _immutableSet(categoryAccountIds),
       settlementAccountIds = _immutableSet(settlementAccountIds),
       tagIds = _immutableSet(tagIds),
       assert(occurredUntil.isAfter(occurredFrom)),
       assert(limit > 0),
       assert(!untaggedOnly || tagIds == null);

  final DateTime occurredFrom;
  final DateTime occurredUntil;
  final BusinessActivityCursor? before;
  final int limit;

  /// 业务活动稳定类型；`null` 表示全部来源，空集合表示没有可匹配来源。
  final Set<String>? activityTypes;

  /// 已由 application 展开并校验的物理分类账户 ID。
  final Set<String>? categoryAccountIds;

  /// 已由 application 校验的资产或负债账户 ID。
  final Set<String>? settlementAccountIds;

  /// 标签按任一命中；与 [untaggedOnly] 互斥。
  final Set<String>? tagIds;
  final bool untaggedOnly;
  final String? counterpartyId;
}

/// 来源返回给公共归并层的业务活动候选。
///
/// 活动身份和业务时间由所属来源决定。展示交易只是可选的列表投影，不参与
/// 活动身份，也不是活动能够被查询、分页或展示的前提。
final class BusinessActivityCandidate {
  const BusinessActivityCandidate({
    required this.activityKey,
    required this.activityAt,
    this.displayTransactionId,
  }) : assert(displayTransactionId == null || displayTransactionId != '');

  final BusinessActivityKey activityKey;
  final DateTime activityAt;
  final String? displayTransactionId;
}

/// 单个来源的一页业务活动候选结果。
///
/// [candidates] 必须已按 `(activityAt DESC, activityKey DESC)` 排序，且不能超过请求
/// limit + 1。来源需要额外读取并返回一条候选来判断本来源是否还有下一页；
/// 因此 `hasMore == true` 时 [candidates] 必须恰好包含 limit + 1 条。
final class BusinessActivitySourcePage {
  BusinessActivitySourcePage({
    required Iterable<BusinessActivityCandidate> candidates,
    required this.hasMore,
  }) : candidates = List.unmodifiable(candidates);

  final List<BusinessActivityCandidate> candidates;
  final bool hasMore;
}

Set<String>? _immutableSet(Set<String>? values) =>
    values == null ? null : Set.unmodifiable(values);
