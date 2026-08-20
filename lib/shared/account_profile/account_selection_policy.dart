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
    AccountSelectionPurpose.reimbursementReceivable =>
      accountMatchesUsage(account, AccountUsage.receivable) &&
          account.profileKey == AccountProfileKind.reimbursement.key,
    AccountSelectionPurpose.receivable => accountMatchesUsage(
      account,
      AccountUsage.receivable,
    ),
  };
}
