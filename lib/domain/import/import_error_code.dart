import '../../core/error/app_error_code.dart';
import '../../core/error/app_exception.dart';

enum ImportErrorCode implements AppErrorCode {
  fatalPlan(code: 'import.plan.fatal', defaultMessage: '导入资料包存在致命错误。'),
  duplicateOperationKey(
    code: 'import.plan.duplicate_operation_key',
    defaultMessage: '当前导入计划存在重复的来源操作键。',
  ),
  selectedGroupBlocked(
    code: 'import.group.blocked',
    defaultMessage: '选中的交易组仍有阻塞问题。',
  ),
  mappingMissing(
    code: 'import.mapping.missing',
    defaultMessage: '来源账户或类别尚未完成映射。',
  ),
  mappingTargetUnavailable(
    code: 'import.mapping.target_unavailable',
    defaultMessage: '映射目标不存在或已归档。',
  ),
  mappingTargetRoleInvalid(
    code: 'import.mapping.target_role_invalid',
    defaultMessage: '映射目标与交易所需账户角色不兼容。',
  ),
  invalidDraftStructure(
    code: 'import.group.invalid_structure',
    defaultMessage: '导入交易组结构不受支持。',
  ),
  invalidDraftValue(
    code: 'import.group.invalid_value',
    defaultMessage: '导入交易的金额或时间参数无效。',
  ),
  batchNotFound(code: 'import.batch.not_found', defaultMessage: '导入批次不存在。'),
  commitFailed(code: 'import.commit.failed', defaultMessage: '导入提交失败，所有更改已回滚。'),
  revertFailed(code: 'import.revert.failed', defaultMessage: '撤销导入失败，所有更改已回滚。');

  const ImportErrorCode({required this.code, required this.defaultMessage});

  @override
  final String code;

  @override
  final String defaultMessage;
}

final class ImportWorkflowException extends AppException {
  ImportWorkflowException(
    super.errorCode, {
    super.message,
    super.cause,
    super.stackTrace,
    this.groupIndex,
  });

  final int? groupIndex;
}
