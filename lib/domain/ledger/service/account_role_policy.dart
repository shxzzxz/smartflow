import '../../../core/error/failure.dart';
import '../port/account_repository.dart';
import '../valobj/account_usage.dart';
import '../valobj/ledger_enum.dart';
import 'account_capability_policy.dart';

class AccountRoleRequirement {
  const AccountRoleRequirement({
    required this.accountId,
    this.expectedTypes = const {},
    this.requiredSubtype,
    this.requiredUsage,
    this.allowReimbursementSubtype = true,
  });

  final int accountId;
  final Set<AccountType> expectedTypes;
  final AccountSubtype? requiredSubtype;
  final AccountUsage? requiredUsage;
  final bool allowReimbursementSubtype;
}

class AccountRoleContext {
  const AccountRoleContext(this.requirements);

  final List<AccountRoleRequirement> requirements;

  factory AccountRoleContext.expense({
    required int paidFromAccountId,
    required int expenseAccountId,
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
    required int receiveAccountId,
    required int incomeAccountId,
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
    required int fromAccountId,
    required int toAccountId,
    int? feeExpenseAccountId,
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
      if (feeExpenseAccountId != null)
        AccountRoleRequirement(
          accountId: feeExpenseAccountId,
          expectedTypes: {AccountType.expense},
        ),
    ]);
  }

  factory AccountRoleContext.refund({required int refundToAccountId}) {
    return AccountRoleContext([
      AccountRoleRequirement(
        accountId: refundToAccountId,
        requiredUsage: AccountUsage.settlement,
      ),
    ]);
  }

  factory AccountRoleContext.reimbursementAdvance({
    required int receivableAccountId,
    required int paidFromAccountId,
    required int expenseCategoryId,
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
    required int receivableAccountId,
    required int receiveAccountId,
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
    required int receivableAccountId,
    required int receiveAccountId,
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
    required int liabilityAccountId,
    required int paidFromAccountId,
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
    required int liabilityAccountId,
    required int receiveAccountId,
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
  const AccountRolePolicy({
    required AccountRepository accountRepository,
    AccountCapabilityPolicy capabilityPolicy = const AccountCapabilityPolicy(),
  }) : _accountRepository = accountRepository,
       _capabilityPolicy = capabilityPolicy;

  final AccountRepository _accountRepository;
  final AccountCapabilityPolicy _capabilityPolicy;

  Future<Failure?> validate(AccountRoleContext context) async {
    final ids = {
      for (final requirement in context.requirements) requirement.accountId,
    };
    if (ids.isEmpty) return null;
    final accounts = await _accountRepository.findByIds(ids);
    final accountsById = {for (final account in accounts) account.id: account};

    for (final requirement in context.requirements) {
      final failure = _capabilityPolicy.validate(
        accountsById[requirement.accountId],
        accountId: requirement.accountId,
        expectedTypes: requirement.expectedTypes,
        requiredSubtype: requirement.requiredSubtype,
        requiredUsage: requirement.requiredUsage,
        allowReimbursementSubtype: requirement.allowReimbursementSubtype,
      );
      if (failure != null) return failure;
    }
    return null;
  }
}
