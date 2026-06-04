import '../../../core/error/app_error_code.dart';

enum CreditErrorCode implements AppErrorCode {
  contractNotFound(code: 'credit.contract.not_found', defaultMessage: '合同不存在。'),
  contractNotActive(
    code: 'credit.contract.not_active',
    defaultMessage: '只有进行中的合同可以编辑。',
  ),
  contractInvalidCommand(
    code: 'credit.contract.invalid_command',
    defaultMessage: '合同参数不完整或不合法。',
  ),
  contractPersistenceConflict(
    code: 'credit.contract.persistence_conflict',
    defaultMessage: '合同数据已变化，请刷新后重试。',
  );

  const CreditErrorCode({required this.code, required this.defaultMessage});

  @override
  final String code;

  @override
  final String defaultMessage;
}
