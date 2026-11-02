import 'business_item_queries.dart';
import 'business_item_read_models.dart';

/// 跨业务来源的业务事项查询用例。
///
/// 实现负责合并各来源锚点、确定全局 `hasMore`、批量加载摘要和校验锚点
/// 交易。来源查询已经完成全部筛选和游标条件，本服务不得补做业务过滤。
abstract interface class BusinessItemQueryService {
  Future<BusinessItemPage> findPage(BusinessItemPageQuery query);

  Stream<BusinessItemPage> watchPage(BusinessItemPageQuery query);
}
