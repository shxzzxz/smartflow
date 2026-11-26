import '../../../core/error/app_error_code.dart';

enum AnalyticsErrorCode implements AppErrorCode {
  invalidView(
    code: 'analytics.asset_view.invalid',
    defaultMessage: '请填写视图名称并选择账户。',
  ),
  invalidGroup(
    code: 'analytics.asset_view.group_invalid',
    defaultMessage: '视图内账户分组不合法，请重新选择。',
  ),
  viewNotFound(
    code: 'analytics.asset_view.not_found',
    defaultMessage: '视图不存在。',
  ),
  nameExists(
    code: 'analytics.asset_view.name_exists',
    defaultMessage: '视图名称已存在。',
  ),
  builtinView(
    code: 'analytics.asset_view.builtin',
    defaultMessage: '默认视图的名称不可修改，也不可删除。',
  ),
  invalidReferences(
    code: 'analytics.asset_view.references_invalid',
    defaultMessage: '账户或分组已变更，请重新选择。',
  ),
  concurrentUpdate(
    code: 'analytics.asset_view.concurrent_update',
    defaultMessage: '视图已被修改，请重新打开后再保存。',
  ),
  invalidConfiguration(
    code: 'analytics.asset_view.configuration_invalid',
    defaultMessage: '视图配置无法读取。',
  );

  const AnalyticsErrorCode({required this.code, required this.defaultMessage});
  @override
  final String code;
  @override
  final String defaultMessage;
}
