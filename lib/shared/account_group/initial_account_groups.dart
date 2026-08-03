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
    id: 'builtin-account-group-funds',
    name: '资金',
    profile: AccountProfileKind.fund,
    sortOrder: 10,
  ),
  InitialAccountGroup(
    id: 'builtin-account-group-credit',
    name: '信用',
    profile: AccountProfileKind.credit,
    sortOrder: 20,
  ),
  InitialAccountGroup(
    id: 'builtin-account-group-loan',
    name: '贷款',
    profile: AccountProfileKind.loan,
    sortOrder: 30,
  ),
  InitialAccountGroup(
    id: 'builtin-account-group-reimbursement',
    name: '报销',
    profile: AccountProfileKind.reimbursement,
    sortOrder: 40,
  ),
];

String? initialAccountGroupIdForProfile(AccountProfileKind profile) {
  for (final group in initialAccountGroups) {
    if (group.profile == profile) return group.id;
  }
  return null;
}
