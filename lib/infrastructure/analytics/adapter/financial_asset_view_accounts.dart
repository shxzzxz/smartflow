import '../../../application/credit/credit_command_api.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../domain/analytics/port/asset_view_account_port.dart';
import '../../../shared/account_profile/account_profile_kind.dart';

class FinancialAssetViewAccounts implements AssetViewAccountPort {
  const FinancialAssetViewAccounts({
    required AccountAppService ledger,
    required CreditAccountAppService credit,
  }) : _ledger = ledger,
       _credit = credit;
  final AccountAppService _ledger;
  final CreditAccountAppService _credit;

  @override
  Future<String> createAccount(AssetViewAccountDraft draft) async {
    if (draft.profile.owner == AccountProfileOwner.ledger) {
      return (await _ledger.createAccount(
        CreateAccountCommand(
          transactionBookId: draft.transactionBookId,
          name: draft.name,
          type: draft.profile.accountType,
          subtype: draft.profile.accountSubtype,
          profileKey: draft.profile.key,
          openingBalance: draft.openingBalance,
          iconKey: draft.iconKey,
          note: draft.note,
        ),
      )).id;
    }
    return (await _credit.createAccount(
      CreateCreditLiabilityAccountCommand(
        transactionBookId: draft.transactionBookId,
        name: draft.name,
        kind: draft.profile == AccountProfileKind.credit
            ? CreditLiabilityAccountKind.credit
            : CreditLiabilityAccountKind.loan,
        openingBalance: draft.openingBalance,
        iconKey: draft.iconKey,
        note: draft.note,
        creditLimit: draft.creditLimit,
        billingDay: draft.billingDay,
        repaymentDay: draft.repaymentDay,
        billingDayToNext: draft.billingDayToNext,
      ),
    )).id;
  }

  @override
  Future<void> editAccount(AssetViewAccountEdit edit) {
    if (edit.profile.owner == AccountProfileOwner.ledger) {
      return _ledger.editAccount(
        EditAccountCommand(
          transactionBookId: edit.transactionBookId,
          id: edit.accountId,
          name: edit.name,
          iconKey: edit.iconKey,
          note: edit.note,
          targetBalance: edit.targetBalance,
        ),
      );
    }
    return _credit.editAccount(
      EditCreditLiabilityAccountCommand(
        transactionBookId: edit.transactionBookId,
        accountId: edit.accountId,
        name: edit.name,
        iconKey: edit.iconKey,
        note: edit.note,
        targetBalance: edit.targetBalance,
        creditLimit: edit.creditLimit,
        billingDay: edit.billingDay,
        repaymentDay: edit.repaymentDay,
        billingDayToNext: edit.billingDayToNext,
      ),
    );
  }
}
