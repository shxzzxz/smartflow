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
  transactionNotFound(
    code: 'ledger.transaction.not_found',
    defaultMessage: '交易不存在。',
  ),
  transactionNotEditable(
    code: 'ledger.transaction.not_editable',
    defaultMessage: '交易当前不可编辑。',
  ),
  accountNotFound(code: 'ledger.account.not_found', defaultMessage: '账户不存在。'),
  accountUnavailable(
    code: 'ledger.account.unavailable',
    defaultMessage: '账户当前不可用。',
  ),
  accountInvalidRole(
    code: 'ledger.account.invalid_role',
    defaultMessage: '账户不能用于当前交易。',
  ),
  accountInvalidCommand(
    code: 'ledger.account.invalid_command',
    defaultMessage: '账户参数不完整或不合法。',
  ),
  accountInUse(
    code: 'ledger.account.in_use',
    defaultMessage: '账户存在业务数据，无法永久删除。',
  ),
  categoryNotFound(code: 'ledger.category.not_found', defaultMessage: '分类不存在。'),
  categoryUnavailable(
    code: 'ledger.category.unavailable',
    defaultMessage: '分类当前不可用。',
  ),
  categoryInUse(code: 'ledger.category.in_use', defaultMessage: '分类已被交易引用。'),
  categoryInvalidCommand(
    code: 'ledger.category.invalid_command',
    defaultMessage: '分类参数不完整或不合法。',
  ),
  categoryInvalidParent(
    code: 'ledger.category.invalid_parent',
    defaultMessage: '父分类不可用。',
  ),
  budgetNotFound(code: 'ledger.budget.not_found', defaultMessage: '预算不存在。'),
  budgetInvalidCommand(
    code: 'ledger.budget.invalid_command',
    defaultMessage: '预算参数不完整或不合法。',
  );

  const LedgerErrorCode({required this.code, required this.defaultMessage});

  @override
  final String code;

  @override
  final String defaultMessage;
}
