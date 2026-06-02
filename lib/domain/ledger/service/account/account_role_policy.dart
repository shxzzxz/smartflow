import 'package:smartflow/core/error/failure.dart';
import '../../entity/account.dart';
import '../../port/account_repository.dart';
import '../../valobj/account_usage.dart';
import '../../valobj/ledger_enum.dart';

class AccountRoleRequirement {
  const AccountRoleRequirement({
    required this.accountId,
    this.expectedTypes = const {},
    this.requiredSubtype,
    this.requiredUsage,
  });

  final String accountId;
  final Set<AccountType> expectedTypes;
  final AccountSubtype? requiredSubtype;
  final AccountUsage? requiredUsage;
}

class AccountRoleContext {
  const AccountRoleContext(this.requirements);

  final List<AccountRoleRequirement> requirements;

  factory AccountRoleContext.expense({
    required String paidFromAccountId,
    required String expenseAccountId,
  }) {
    return AccountRoleContext([
      AccountRoleRequirement(
        accountId: paidFromAccountId,
        requiredUsage: AccountUsage.settlement,
      ),
      AccountRoleRequirement(
        accountId: expenseAccountId,
        expectedTypes: {AccountType.expense},
      ),
    ]);
  }

  factory AccountRoleContext.income({
    required String receiveAccountId,
    required String incomeAccountId,
  }) {
    return AccountRoleContext([
      AccountRoleRequirement(
        accountId: receiveAccountId,
        requiredUsage: AccountUsage.settlement,
      ),
      AccountRoleRequirement(
        accountId: incomeAccountId,
        expectedTypes: {AccountType.income},
      ),
    ]);
  }

  factory AccountRoleContext.transfer({
    required String fromAccountId,
    required String toAccountId,
  }) {
    return AccountRoleContext([
      AccountRoleRequirement(
        accountId: fromAccountId,
        requiredUsage: AccountUsage.settlement,
      ),
      AccountRoleRequirement(
        accountId: toAccountId,
        requiredUsage: AccountUsage.settlement,
      ),
    ]);
  }

  factory AccountRoleContext.refund({required String refundToAccountId}) {
    return AccountRoleContext([
      AccountRoleRequirement(
        accountId: refundToAccountId,
        requiredUsage: AccountUsage.settlement,
      ),
    ]);
  }

  factory AccountRoleContext.reimbursementAdvance({
    required String receivableAccountId,
    required String paidFromAccountId,
    required String expenseCategoryId,
  }) {
    return AccountRoleContext([
      AccountRoleRequirement(
        accountId: receivableAccountId,
        requiredUsage: AccountUsage.reimbursement,
      ),
      AccountRoleRequirement(
        accountId: paidFromAccountId,
        requiredUsage: AccountUsage.settlement,
      ),
      AccountRoleRequirement(
        accountId: expenseCategoryId,
        expectedTypes: {AccountType.expense},
      ),
    ]);
  }

  factory AccountRoleContext.reimbursementReceipt({
    required String receivableAccountId,
    required String receiveAccountId,
  }) {
    return AccountRoleContext([
      AccountRoleRequirement(
        accountId: receiveAccountId,
        requiredUsage: AccountUsage.settlement,
      ),
      AccountRoleRequirement(
        accountId: receivableAccountId,
        requiredUsage: AccountUsage.reimbursement,
      ),
    ]);
  }

  factory AccountRoleContext.reimbursementClose({
    required String receivableAccountId,
    required String receiveAccountId,
    required bool receivesCash,
  }) {
    return AccountRoleContext([
      if (receivesCash)
        AccountRoleRequirement(
          accountId: receiveAccountId,
          requiredUsage: AccountUsage.settlement,
        ),
      AccountRoleRequirement(
        accountId: receivableAccountId,
        requiredUsage: AccountUsage.reimbursement,
      ),
    ]);
  }

  factory AccountRoleContext.repayment({
    required String liabilityAccountId,
    required String paidFromAccountId,
  }) {
    return AccountRoleContext([
      AccountRoleRequirement(
        accountId: liabilityAccountId,
        requiredUsage: AccountUsage.repaymentTarget,
      ),
      AccountRoleRequirement(
        accountId: paidFromAccountId,
        requiredUsage: AccountUsage.repaymentSource,
      ),
    ]);
  }

  factory AccountRoleContext.borrowing({
    required String liabilityAccountId,
    required String receiveAccountId,
  }) {
    return AccountRoleContext([
      AccountRoleRequirement(
        accountId: liabilityAccountId,
        requiredUsage: AccountUsage.borrowingLiability,
      ),
      AccountRoleRequirement(
        accountId: receiveAccountId,
        requiredUsage: AccountUsage.fund,
      ),
    ]);
  }
}

class AccountRolePolicy {
  const AccountRolePolicy({required AccountRepository accountRepository})
    : _accountRepository = accountRepository;

  final AccountRepository _accountRepository;

  Future<Failure?> validate(AccountRoleContext context) async {
    final ids = {
      for (final requirement in context.requirements) requirement.accountId,
    };
    if (ids.isEmpty) return null;
    final accounts = await _accountRepository.findByIds(ids);
    final accountsById = {for (final account in accounts) account.id: account};

    for (final requirement in context.requirements) {
      final failure = _validateRequirement(
        accountsById[requirement.accountId],
        requirement,
      );
      if (failure != null) return failure;
    }
    return null;
  }

  Failure? _validateRequirement(
    Account? account,
    AccountRoleRequirement requirement,
  ) {
    if (account == null) {
      return Failure(
        code: 'account_not_found',
        message: 'Account ${requirement.accountId} does not exist.',
      );
    }
    if (account.archivedAt != null) {
      return Failure(
        code: 'account_archived',
        message: 'Account ${requirement.accountId} is archived.',
      );
    }
    if (requirement.expectedTypes.isNotEmpty &&
        !requirement.expectedTypes.contains(account.type)) {
      return Failure(
        code: 'account_role_invalid',
        message:
            'Account ${requirement.accountId} cannot be used for this transaction.',
      );
    }
    if (requirement.requiredSubtype != null &&
        account.subtype != requirement.requiredSubtype) {
      return Failure(
        code: 'account_subtype_invalid',
        message:
            'Account ${requirement.accountId} cannot be used for this transaction.',
      );
    }
    if (requirement.requiredUsage != null &&
        !accountMatchesUsage(account, requirement.requiredUsage!)) {
      return Failure(
        code: 'account_role_invalid',
        message:
            'Account ${requirement.accountId} cannot be used for this transaction.',
      );
    }
    return null;
  }
}
