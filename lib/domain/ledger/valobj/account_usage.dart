import '../entity/account.dart';
import 'ledger_enum.dart';

enum AccountUsage {
  settlement,
  transfer,
  expenseSettlement,
  fund,
  repaymentTarget,
  repaymentSource,
  liability,
  receivable,
}

bool accountMatchesUsage(Account account, AccountUsage usage) {
  if (account.archivedAt != null) {
    return false;
  }
  // The ghost account is a system equity placeholder for source facts that
  // explicitly have no settlement account. It may only stand in for the
  // settlement side (and therefore repayment source), never for funds,
  // liabilities, or advance receivables.
  if (account.systemKey == SystemKey.ghostAccount) {
    return usage == AccountUsage.settlement ||
        usage == AccountUsage.expenseSettlement ||
        usage == AccountUsage.repaymentSource;
  }
  return switch (usage) {
    AccountUsage.settlement =>
      accountMatchesUsage(account, AccountUsage.fund) ||
          account.type == AccountType.liability,
    AccountUsage.transfer =>
      accountMatchesUsage(account, AccountUsage.settlement) ||
          (account.type == AccountType.asset &&
              account.subtype == AccountSubtype.prepaidExpense),
    AccountUsage.expenseSettlement =>
      accountMatchesUsage(account, AccountUsage.settlement) ||
          accountMatchesUsage(account, AccountUsage.receivable) ||
          (account.type == AccountType.asset &&
              account.subtype == AccountSubtype.prepaidExpense),
    AccountUsage.fund =>
      account.type == AccountType.asset &&
          account.subtype == AccountSubtype.fund,
    AccountUsage.repaymentTarget || AccountUsage.liability =>
      account.type == AccountType.liability &&
          (account.subtype == AccountSubtype.payable ||
              account.subtype == AccountSubtype.loan),
    AccountUsage.repaymentSource => accountMatchesUsage(
      account,
      AccountUsage.fund,
    ),
    AccountUsage.receivable =>
      account.type == AccountType.asset &&
          account.subtype == AccountSubtype.receivable,
  };
}
