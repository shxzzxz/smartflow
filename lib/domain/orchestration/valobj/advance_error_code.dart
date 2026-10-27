import '../../../core/error/app_error_code.dart';

enum AdvanceErrorCode implements AppErrorCode {
  transactionNotFound(
    code: 'orchestration.advance.transaction_not_found',
    defaultMessage: '垫付相关交易不存在。',
  ),
  caseNotFound(
    code: 'orchestration.advance.case_not_found',
    defaultMessage: '垫付编排实例不存在。',
  ),
  invalidCommand(
    code: 'orchestration.advance.invalid_command',
    defaultMessage: '垫付参数不完整或不合法。',
  ),
  conversionNotAllowed(
    code: 'orchestration.advance.conversion_not_allowed',
    defaultMessage: '当前垫付场景不支持用途转换。',
  );

  const AdvanceErrorCode({required this.code, required this.defaultMessage});

  @override
  final String code;

  @override
  final String defaultMessage;
}
