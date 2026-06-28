import '../../../application/credit/credit_query_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../shared/account_profile/account_profile_kind.dart';

class AccountView {
  const AccountView({
    required this.id,
    required this.name,
    required this.kind,
    required this.balance,
    required this.iconKey,
    this.note,
    this.creditLimit,
    this.billingDay,
    this.repaymentDay,
    this.billingStartPeriod,
    this.billingDayToNext,
  });

  final String id;
  final String name;
  final AccountProfileKind kind;
  final Money balance;
  final String? iconKey;
  final String? note;
  final Money? creditLimit;
  final int? billingDay;
  final int? repaymentDay;
  final BillPeriod? billingStartPeriod;
  final bool? billingDayToNext;

  bool get isCredit => kind == AccountProfileKind.credit;
  bool get isLoan => kind == AccountProfileKind.loan;
  bool get isCreditLiability => isCredit || isLoan;
  bool get isLiability => kind.accountType == AccountType.liability;
  AccountType get accountType => kind.accountType;
  AccountSubtype? get accountSubtype => kind.accountSubtype;
}

AccountView buildAccountView(
  Account account,
  Map<String, CreditLiabilityAccount> creditByAccountId,
) {
  final kind = accountProfileKindForAccount(account);
  final creditAccount = creditByAccountId[account.id];
  if ((kind == AccountProfileKind.credit || kind == AccountProfileKind.loan) &&
      creditAccount == null) {
    throw StateError(
      'Missing credit liability extension for account ${account.id}.',
    );
  }

  return AccountView(
    id: account.id,
    name: account.name,
    kind: kind,
    balance: account.balance,
    iconKey: account.iconKey ?? kind.iconKey,
    note: account.note,
    creditLimit: creditAccount?.creditLimit,
    billingDay: creditAccount?.billingDay,
    repaymentDay: creditAccount?.repaymentDay,
    billingStartPeriod: creditAccount?.billingStartPeriod,
    billingDayToNext: creditAccount?.billingDayToNext,
  );
}

List<AccountView> buildAccountViews(
  List<Account> accounts,
  Map<String, CreditLiabilityAccount> creditByAccountId,
) {
  return [
    for (final account in accounts)
      buildAccountView(account, creditByAccountId),
  ];
}

AccountProfileKind accountProfileKindForAccount(Account account) {
  return accountProfileKindForAccountType(
    type: account.type,
    subtype: account.subtype,
    profileKey: account.profileKey,
  );
}
