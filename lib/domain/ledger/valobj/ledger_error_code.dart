import '../../../core/error/app_error_code.dart';

enum LedgerErrorCode implements AppErrorCode {
  transactionInvalidCommand(
    code: 'ledger.transaction.invalid_command',
    defaultMessage: '交易参数不完整或不合法。',
  ),
  transactionPostingFailed(
    code: 'ledger.transaction.posting_failed',
    defaultMessage: '交易入账失败。',
  ),
  accountNotFound(code: 'ledger.account.not_found', defaultMessage: '账户不存在。'),
  accountUnavailable(
    code: 'ledger.account.unavailable',
    defaultMessage: '账户当前不可用。',
  ),
  accountInvalidRole(
    code: 'ledger.account.invalid_role',
    defaultMessage: '账户不能用于当前交易。',
  );

  const LedgerErrorCode({required this.code, required this.defaultMessage});

  @override
  final String code;

  @override
  final String defaultMessage;
}
