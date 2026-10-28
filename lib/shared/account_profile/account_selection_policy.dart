import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/valobj/account_usage.dart';

import 'account_profile_kind.dart';
import 'account_selection_purpose.dart';

bool accountMatchesSelectionPurpose(
  Account account,
  AccountSelectionPurpose purpose,
) {
  return switch (purpose) {
    AccountSelectionPurpose.settlement =>
      accountMatchesUsage(account, AccountUsage.settlement) &&
          account.profileKey != AccountProfileKind.loan.key,
    // Ledger accepts every receivable subtype as an expense settlement role.
    // The product form exposes only the ordinary receivable profile.
    AccountSelectionPurpose.expenseSettlement =>
      (accountMatchesUsage(account, AccountUsage.settlement) &&
              account.profileKey != AccountProfileKind.loan.key) ||
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
