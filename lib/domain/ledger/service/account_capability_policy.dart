import '../../../core/error/failure.dart';
import '../entity/account.dart';
import '../valobj/account_usage.dart';
import '../valobj/ledger_enum.dart';

/// 账户能力策略:判断已加载的 [Account] 能否承担本次入账中给定的角色。
///
/// 不打数据库;caller 先 load,policy 只做规则判定。
/// 校验维度:存在、未归档、type、subtype、usage、报销子类型黑名单。
class AccountCapabilityPolicy {
  const AccountCapabilityPolicy();

  Failure? validate(
    Account? account, {
    required String accountId,
    Set<AccountType> expectedTypes = const {},
    AccountSubtype? requiredSubtype,
    AccountUsage? requiredUsage,
    bool allowReimbursementSubtype = true,
  }) {
    if (account == null) {
      return Failure(
        code: 'account_not_found',
        message: 'Account $accountId does not exist.',
      );
    }
    if (account.archivedAt != null) {
      return Failure(
        code: 'account_archived',
        message: 'Account $accountId is archived.',
      );
    }
    if (expectedTypes.isNotEmpty && !expectedTypes.contains(account.type)) {
      return Failure(
        code: 'account_role_invalid',
        message: 'Account $accountId cannot be used for this transaction.',
      );
    }
    if (requiredSubtype != null && account.subtype != requiredSubtype) {
      return Failure(
        code: 'account_subtype_invalid',
        message: 'Account $accountId cannot be used for this transaction.',
      );
    }
    if (requiredUsage != null && !accountMatchesUsage(account, requiredUsage)) {
      return Failure(
        code: 'account_role_invalid',
        message: 'Account $accountId cannot be used for this transaction.',
      );
    }
    if (!allowReimbursementSubtype &&
        account.subtype == AccountSubtype.reimbursement) {
      return Failure(
        code: 'account_subtype_invalid',
        message: 'Reimbursement account cannot be used as settlement account.',
      );
    }
    return null;
  }
}
