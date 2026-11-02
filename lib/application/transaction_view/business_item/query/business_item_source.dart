import 'business_item_queries.dart';
import 'business_item_read_models.dart';

/// 单个业务事项场景的读侧来源。
///
/// 来源负责解释自己的 owner、锚点、业务筛选和联查，但不得返回未经筛选的
/// 原始交易页。`watchAnchorPage` 必须响应该来源涉及的账务和业务表变化。
abstract interface class BusinessItemSource {
  /// 稳定的来源标识，仅用于装配、诊断和测试。
  String get sourceKey;

  /// 当前来源能够产生的事项类型，用于公共查询跳过无关来源。
  Set<String> get supportedItemTypes;

  Future<BusinessItemSourcePage> findAnchorPage(BusinessItemPageQuery query);

  Stream<BusinessItemSourcePage> watchAnchorPage(BusinessItemPageQuery query);

  /// 批量加载这一页内属于当前来源的事项摘要。
  ///
  /// 实现不得逐事项查询。返回结果应覆盖传入且属于该来源的全部 key。
  Future<Map<BusinessItemKey, BusinessItemSummary>> findSummaries(
    Set<BusinessItemKey> itemKeys,
  );
}
