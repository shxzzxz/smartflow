import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/valobj/account_usage.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

import 'account_profile_kind.dart';
import 'account_selection_purpose.dart';

bool accountMatchesSelectionPurpose(
  Account account,
  AccountSelectionPurpose purpose,
) {
  return switch (purpose) {
    AccountSelectionPurpose.settlement =>
      accountMatchesUsage(account, AccountUsage.settlement) &&
          account.profileKey != AccountProfileKind.loan.key &&
          account.profileKey != AccountProfileKind.deferredIncome.key,
    // Ledger accepts every receivable subtype as an expense settlement role.
    // The product form exposes only the ordinary receivable profile.
    AccountSelectionPurpose.expenseSettlement =>
      (accountMatchesUsage(account, AccountUsage.settlement) &&
              account.profileKey != AccountProfileKind.loan.key &&
              account.profileKey != AccountProfileKind.deferredIncome.key) ||
          (accountMatchesUsage(account, AccountUsage.receivable) &&
              account.profileKey == AccountProfileKind.receivable.key),
    AccountSelectionPurpose.fund => accountMatchesUsage(
      account,
      AccountUsage.fund,
    ),
    AccountSelectionPurpose.repaymentTarget => accountMatchesUsage(
      account,
      AccountUsage.repaymentTarget,
    ),
    AccountSelectionPurpose.repaymentSource =>
      accountMatchesUsage(account, AccountUsage.repaymentSource) &&
          account.profileKey != AccountProfileKind.loan.key,
    AccountSelectionPurpose.borrowingLiability => accountMatchesUsage(
      account,
      AccountUsage.liability,
    ),
    AccountSelectionPurpose.advanceReceivable ||
    AccountSelectionPurpose.ordinaryReceivable ||
    AccountSelectionPurpose.receivable => accountMatchesUsage(
      account,
      AccountUsage.receivable,
    ),
    AccountSelectionPurpose.prepaidExpense =>
      account.archivedAt == null &&
          account.type == AccountType.asset &&
          account.subtype == AccountSubtype.prepaidExpense,
    AccountSelectionPurpose.deferredIncome =>
      account.archivedAt == null &&
          account.type == AccountType.liability &&
          account.subtype == AccountSubtype.deferredIncome,
  };
}

List<Account> accountsMatchingSelectionPurpose(
  Iterable<Account> accounts,
  AccountSelectionPurpose purpose,
) {
  return List.unmodifiable(
    accounts.where(
      (account) => accountMatchesSelectionPurpose(account, purpose),
    ),
  );
}
