import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

enum AccountProfileKind {
  fund(
    key: 'ledger.fund',
    label: '资金账户',
    iconKey: 'alipay',
    accountType: AccountType.asset,
  ),
  reimbursement(
    key: 'ledger.reimbursement',
    label: '报销账户',
    iconKey: 'reimburse',
    accountType: AccountType.asset,
    accountSubtype: AccountSubtype.reimbursement,
  ),
  credit(
    key: 'credit.credit',
    label: '信用账户',
    iconKey: 'cmb_credit_card',
    accountType: AccountType.liability,
  ),
  loan(
    key: 'credit.loan',
    label: '贷款账户',
    iconKey: 'loan',
    accountType: AccountType.liability,
  );

  const AccountProfileKind({
    required this.key,
    required this.label,
    required this.iconKey,
    required this.accountType,
    this.accountSubtype,
  });

  final String key;
  final String label;
  final String iconKey;
  final AccountType accountType;
  final AccountSubtype? accountSubtype;

  static AccountProfileKind? fromKey(String? key) {
    if (key == null) return null;
    for (final kind in values) {
      if (kind.key == key) return kind;
    }
    return null;
  }
}

AccountProfileKind accountProfileKindForAccountType({
  required AccountType type,
  required AccountSubtype? subtype,
  required String? profileKey,
}) {
  final profile = AccountProfileKind.fromKey(profileKey);
  if (profile != null) return profile;
  if (type == AccountType.liability) return AccountProfileKind.credit;
  if (subtype == AccountSubtype.reimbursement) {
    return AccountProfileKind.reimbursement;
  }
  return AccountProfileKind.fund;
}
