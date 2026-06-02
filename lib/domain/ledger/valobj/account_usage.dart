import '../entity/account.dart';
import 'ledger_enum.dart';

enum AccountUsage {
  settlement,
  fund,
  credit,
  loan,
  repaymentTarget,
  repaymentSource,
  borrowingLiability,
  reimbursement,
}

bool accountMatchesUsage(Account account, AccountUsage usage) {
  if (account.archivedAt != null) {
    return false;
  }
  return switch (usage) {
    AccountUsage.settlement =>
      accountMatchesUsage(account, AccountUsage.fund) ||
          accountMatchesUsage(account, AccountUsage.credit),
    AccountUsage.fund =>
      account.type == AccountType.asset &&
          account.subtype != AccountSubtype.reimbursement,
    AccountUsage.credit =>
      account.type == AccountType.liability &&
          account.subtype != AccountSubtype.loan,
    AccountUsage.loan =>
      account.type == AccountType.liability &&
          account.subtype == AccountSubtype.loan,
    AccountUsage.repaymentTarget => account.type == AccountType.liability,
    AccountUsage.repaymentSource => accountMatchesUsage(
      account,
      AccountUsage.settlement,
    ),
    AccountUsage.borrowingLiability => account.type == AccountType.liability,
    AccountUsage.reimbursement =>
      account.type == AccountType.asset &&
          account.subtype == AccountSubtype.reimbursement,
  };
}
