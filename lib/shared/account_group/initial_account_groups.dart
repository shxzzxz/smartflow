import '../account_profile/account_profile_kind.dart';

class InitialAccountGroup {
  const InitialAccountGroup({
    required this.id,
    required this.name,
    required this.profile,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final AccountProfileKind profile;
  final int sortOrder;
}

const initialAccountGroups = [
  InitialAccountGroup(
    id: 'builtin-account-group-receivable',
    name: '应收账户',
    profile: AccountProfileKind.receivable,
    sortOrder: 20,
  ),
  InitialAccountGroup(
    id: 'builtin-account-group-payable',
    name: '应付账户',
    profile: AccountProfileKind.payable,
    sortOrder: 30,
  ),
  InitialAccountGroup(
    id: 'builtin-account-group-funds',
    name: '资金',
    profile: AccountProfileKind.fund,
    sortOrder: 10,
  ),
  InitialAccountGroup(
    id: 'builtin-account-group-credit',
    name: '信用',
    profile: AccountProfileKind.credit,
    sortOrder: 40,
  ),
  InitialAccountGroup(
    id: 'builtin-account-group-loan',
    name: '贷款',
    profile: AccountProfileKind.loan,
    sortOrder: 50,
  ),
  InitialAccountGroup(
    id: 'builtin-account-group-reimbursement',
    name: '报销',
    profile: AccountProfileKind.reimbursement,
    sortOrder: 60,
  ),
];

String? initialAccountGroupIdForProfile(AccountProfileKind profile) {
  for (final group in initialAccountGroups) {
    if (group.profile == profile) return group.id;
  }
  return null;
}
