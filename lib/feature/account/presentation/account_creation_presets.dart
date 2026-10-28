import '../../../shared/account_profile/account_profile_kind.dart';

class AccountCreationGroup {
  const AccountCreationGroup({
    required this.id,
    required this.label,
    required this.presets,
  });

  final String id;
  final String label;
  final List<AccountCreationPreset> presets;
}

class AccountCreationPreset {
  const AccountCreationPreset({
    required this.id,
    required this.label,
    required this.kind,
    required this.iconKey,
    this.defaultName,
  });

  final String id;
  final String label;
  final AccountProfileKind kind;
  final String iconKey;
  final String? defaultName;

  String get routeLocation =>
      Uri(path: '/account/new', queryParameters: {'preset': id}).toString();
}

const accountCreationGroups = <AccountCreationGroup>[
  AccountCreationGroup(
    id: 'fund',
    label: '资金账户',
    presets: [
      AccountCreationPreset(
        id: 'wechat',
        label: '微信',
        kind: AccountProfileKind.fund,
        iconKey: 'wechat_pay',
        defaultName: '微信',
      ),
      AccountCreationPreset(
        id: 'alipay',
        label: '支付宝',
        kind: AccountProfileKind.fund,
        iconKey: 'alipay',
        defaultName: '支付宝',
      ),
      AccountCreationPreset(
        id: 'boc',
        label: '中国银行',
        kind: AccountProfileKind.fund,
        iconKey: 'boc_debit_card',
        defaultName: '中国银行',
      ),
      AccountCreationPreset(
        id: 'icbc',
        label: '工商银行',
        kind: AccountProfileKind.fund,
        iconKey: 'icbc',
        defaultName: '工商银行',
      ),
      AccountCreationPreset(
        id: 'ccb',
        label: '建设银行',
        kind: AccountProfileKind.fund,
        iconKey: 'ccb',
        defaultName: '建设银行',
      ),
      AccountCreationPreset(
        id: 'abc',
        label: '农业银行',
        kind: AccountProfileKind.fund,
        iconKey: 'abc',
        defaultName: '农业银行',
      ),
      AccountCreationPreset(
        id: 'cmb',
        label: '招商银行',
        kind: AccountProfileKind.fund,
        iconKey: 'cmb_credit_card',
        defaultName: '招商银行',
      ),
      AccountCreationPreset(
        id: 'fund-account',
        label: '资金账户',
        kind: AccountProfileKind.fund,
        iconKey: 'bank-account',
        defaultName: '资金账户',
      ),
    ],
  ),
  AccountCreationGroup(
    id: 'credit',
    label: '信贷账户',
    presets: [
      AccountCreationPreset(
        id: 'huabei',
        label: '花呗',
        kind: AccountProfileKind.credit,
        iconKey: 'huabei',
        defaultName: '花呗',
      ),
      AccountCreationPreset(
        id: 'meituan-pay-later',
        label: '美团月付',
        kind: AccountProfileKind.credit,
        iconKey: 'meituan',
        defaultName: '美团月付',
      ),
      AccountCreationPreset(
        id: 'jiebei',
        label: '借呗',
        kind: AccountProfileKind.loan,
        iconKey: 'jiebei',
        defaultName: '借呗',
      ),
      AccountCreationPreset(
        id: 'mortgage',
        label: '房贷',
        kind: AccountProfileKind.loan,
        iconKey: 'mortgage-account',
        defaultName: '房贷',
      ),
      AccountCreationPreset(
        id: 'car-loan',
        label: '车贷',
        kind: AccountProfileKind.loan,
        iconKey: 'car-loan-account',
        defaultName: '车贷',
      ),
      AccountCreationPreset(
        id: 'credit-account',
        label: '信用账户',
        kind: AccountProfileKind.credit,
        iconKey: 'credit-card',
        defaultName: '信用账户',
      ),
      AccountCreationPreset(
        id: 'loan-account',
        label: '贷款账户',
        kind: AccountProfileKind.loan,
        iconKey: 'loan',
        defaultName: '贷款账户',
      ),
    ],
  ),
  AccountCreationGroup(
    id: 'relations',
    label: '往来',
    presets: [
      AccountCreationPreset(
        id: 'reimbursement',
        label: '报销',
        kind: AccountProfileKind.reimbursement,
        iconKey: 'reimburse',
        defaultName: '报销',
      ),
      AccountCreationPreset(
        id: 'deposit',
        label: '押金',
        kind: AccountProfileKind.receivable,
        iconKey: 'prepaid-card',
        defaultName: '押金',
      ),
      AccountCreationPreset(
        id: 'buy-now-pay-later',
        label: '先享后付',
        kind: AccountProfileKind.payable,
        iconKey: 'buy-now-pay-later',
        defaultName: '先享后付',
      ),
      AccountCreationPreset(
        id: 'receivable',
        label: '应收账户',
        kind: AccountProfileKind.receivable,
        iconKey: 'loan_out',
        defaultName: '应收账户',
      ),
      AccountCreationPreset(
        id: 'payable',
        label: '应付账户',
        kind: AccountProfileKind.payable,
        iconKey: 'loan_in',
        defaultName: '应付账户',
      ),
    ],
  ),
];

AccountCreationPreset? accountCreationPresetForId(String? id) {
  if (id == null) return null;
  for (final group in accountCreationGroups) {
    for (final preset in group.presets) {
      if (preset.id == id) return preset;
    }
  }
  return null;
}
