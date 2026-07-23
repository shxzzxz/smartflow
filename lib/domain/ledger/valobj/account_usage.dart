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
  // The ghost account is a system equity placeholder for source facts that
  // explicitly have no settlement account. It may only stand in for the
  // settlement side (and therefore repayment source), never for funds,
  // liabilities, or reimbursement receivables.
  if (account.systemKey == SystemKey.ghostAccount) {
    return usage == AccountUsage.settlement ||
        usage == AccountUsage.repaymentSource;
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
