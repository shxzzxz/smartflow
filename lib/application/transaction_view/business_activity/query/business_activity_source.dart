import 'business_activity_queries.dart';
import 'business_activity_read_models.dart';

/// 单个业务活动场景的读侧来源。
///
/// 来源负责解释自己的活动身份、业务时间、筛选和联查，但不得返回未经筛选的
/// 原始交易页。`watchCandidatePage` 必须响应该来源涉及的账务和业务表变化。
abstract interface class BusinessActivitySource {
  /// 稳定的来源标识，仅用于装配、诊断和测试。
  String get sourceKey;

  /// 当前来源能够产生的事项类型，用于公共查询跳过无关来源。
  Set<String> get supportedActivityTypes;

  Future<BusinessActivitySourcePage> findCandidatePage(
    BusinessActivityPageQuery query,
  );

  Stream<BusinessActivitySourcePage> watchCandidatePage(
    BusinessActivityPageQuery query,
  );

  /// 批量加载这一页内属于当前来源的事项摘要。
  ///
  /// [candidates] 是当前来源在合并后实际入选的事项。实现不得逐事项查询，也不得
  /// 重复实现账务聚合；需要账务事实时调用账务核心的通用查询，并转换为统一的
  /// [BusinessActivitySummary]。
  ///
  /// 返回结果应覆盖 [candidates] 中的全部 key。
  Future<Map<BusinessActivityKey, BusinessActivitySummary>> findSummaries(
    Iterable<BusinessActivityCandidate> candidates,
  );

  /// Watches summaries for an already selected, bounded set of candidates.
  ///
  /// Implementations must not discover activities outside [candidates].
  Stream<Map<BusinessActivityKey, BusinessActivitySummary>> watchSummaries(
    Iterable<BusinessActivityCandidate> candidates,
  );
}
