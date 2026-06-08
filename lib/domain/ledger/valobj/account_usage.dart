import '../entity/account.dart';
import 'ledger_enum.dart';

enum AccountUsage {
  settlement,
  fund,
  repaymentTarget,
  repaymentSource,
  borrowingLiability,
  reimbursementReceivable,
}

bool accountMatchesUsage(Account account, AccountUsage usage) {
  if (account.archivedAt != null) {
    return false;
  }
  return switch (usage) {
    AccountUsage.settlement =>
      accountMatchesUsage(account, AccountUsage.fund) ||
          account.type == AccountType.liability,
    AccountUsage.fund =>
      account.type == AccountType.asset &&
          account.subtype != AccountSubtype.reimbursement,
    AccountUsage.repaymentTarget => account.type == AccountType.liability,
    AccountUsage.repaymentSource => accountMatchesUsage(
      account,
      AccountUsage.settlement,
    ),
    AccountUsage.borrowingLiability => account.type == AccountType.liability,
    AccountUsage.reimbursementReceivable =>
      account.type == AccountType.asset &&
          account.subtype == AccountSubtype.reimbursement,
  };
}
