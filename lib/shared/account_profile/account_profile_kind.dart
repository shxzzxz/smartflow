import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

enum AccountProfileOwner { ledger, credit }

enum AccountProfileKind {
  fund(
    key: 'ledger.fund',
    label: '资金账户',
    iconKey: 'alipay',
    owner: AccountProfileOwner.ledger,
    accountType: AccountType.asset,
    accountSubtype: AccountSubtype.fund,
  ),
  reimbursement(
    key: 'ledger.reimbursement',
    label: '报销账户',
    iconKey: 'reimburse',
    owner: AccountProfileOwner.ledger,
    accountType: AccountType.asset,
    accountSubtype: AccountSubtype.receivable,
  ),
  receivable(
    key: 'ledger.receivable',
    label: '应收账户',
    iconKey: 'loan_out',
    owner: AccountProfileOwner.ledger,
    accountType: AccountType.asset,
    accountSubtype: AccountSubtype.receivable,
  ),
  payable(
    key: 'ledger.payable',
    label: '应付账户',
    iconKey: 'loan_in',
    owner: AccountProfileOwner.ledger,
    accountType: AccountType.liability,
    accountSubtype: AccountSubtype.payable,
  ),
  credit(
    key: 'credit.credit',
    label: '信用账户',
    iconKey: 'cmb_credit_card',
    owner: AccountProfileOwner.credit,
    accountType: AccountType.liability,
    accountSubtype: AccountSubtype.payable,
  ),
  loan(
    key: 'credit.loan',
    label: '贷款账户',
    iconKey: 'loan',
    owner: AccountProfileOwner.credit,
    accountType: AccountType.liability,
    accountSubtype: AccountSubtype.loan,
  );

  const AccountProfileKind({
    required this.key,
    required this.label,
    required this.iconKey,
    required this.owner,
    required this.accountType,
    required this.accountSubtype,
  });

  final String key;
  final String label;
  final String iconKey;
  final AccountProfileOwner owner;
  final AccountType accountType;
  final AccountSubtype accountSubtype;

  static AccountProfileKind? fromKey(String? key) {
    if (key == null) return null;
    for (final kind in values) {
      if (kind.key == key) return kind;
    }
    return null;
  }
}

bool isAccountProfileCompatible({
  required AccountType type,
  required AccountSubtype? subtype,
  required String? profileKey,
}) {
  final profile = AccountProfileKind.fromKey(profileKey);
  return profile != null &&
      profile.accountType == type &&
      profile.accountSubtype == subtype;
}

AccountProfileKind accountProfileKindForAccountType({
  required AccountType type,
  required AccountSubtype? subtype,
  required String? profileKey,
}) {
  final profile = AccountProfileKind.fromKey(profileKey);
  if (profile != null &&
      isAccountProfileCompatible(
        type: type,
        subtype: subtype,
        profileKey: profileKey,
      )) {
    return profile;
  }
  throw StateError(
    'Unknown or incompatible account profile: '
    'type=${type.name}, subtype=${subtype?.name}, profileKey=$profileKey',
  );
}
