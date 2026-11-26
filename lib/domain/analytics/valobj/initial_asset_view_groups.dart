import '../../../shared/account_profile/account_profile_kind.dart';
import '../../../core/error/app_exception.dart';
import '../entity/asset_view.dart';
import 'analytics_error_code.dart';

const _definitions = [
  (
    id: 'builtin-account-group-funds',
    name: '资金',
    profile: AccountProfileKind.fund,
  ),
  (
    id: 'builtin-account-group-receivable',
    name: '应收账户',
    profile: AccountProfileKind.receivable,
  ),
  (
    id: 'builtin-account-group-payable',
    name: '应付账户',
    profile: AccountProfileKind.payable,
  ),
  (
    id: 'builtin-account-group-credit',
    name: '信用',
    profile: AccountProfileKind.credit,
  ),
  (
    id: 'builtin-account-group-loan',
    name: '贷款',
    profile: AccountProfileKind.loan,
  ),
  (
    id: 'builtin-account-group-reimbursement',
    name: '报销',
    profile: AccountProfileKind.reimbursement,
  ),
  (
    id: 'builtin-account-group-prepaid-expense',
    name: '预付',
    profile: AccountProfileKind.prepaidExpense,
  ),
  (
    id: 'builtin-account-group-deferred-income',
    name: '预收',
    profile: AccountProfileKind.deferredIncome,
  ),
];

List<AssetViewGroup> initialAssetViewGroups() => [
  for (final definition in _definitions)
    AssetViewGroup(id: definition.id, name: definition.name),
];

String initialAssetViewGroupIdForProfile(AccountProfileKind profile) =>
    _definitions.firstWhere((item) => item.profile == profile).id;

String? initialAssetViewGroupId(AssetView view, AccountProfileKind profile) {
  final id = initialAssetViewGroupIdForProfile(profile);
  return view.groups.any((group) => group.id == id) ? id : null;
}

AssetView configureAssetViewAccounts({
  required String id,
  required String name,
  required Iterable<String> accountIds,
  required Map<String, AccountProfileKind> profiles,
  AssetView? source,
  int sortOrder = 0,
  int version = 0,
}) {
  final requested = accountIds.toList();
  final ids = requested.toSet();
  final groups = source?.groups ?? initialAssetViewGroups();
  final groupIds = groups.map((group) => group.id).toSet();
  final assignments = {
    for (final entry
        in source?.accountGroupIds.entries ?? <MapEntry<String, String>>[])
      if (ids.contains(entry.key)) entry.key: entry.value,
  };
  for (final accountId in ids.difference(source?.accountIds.toSet() ?? {})) {
    final profile = profiles[accountId];
    if (profile == null) {
      throw BusinessException(AnalyticsErrorCode.invalidReferences);
    }
    final groupId = initialAssetViewGroupIdForProfile(profile);
    if (groupIds.contains(groupId)) assignments[accountId] = groupId;
  }
  return AssetView(
    id: id,
    name: name,
    accountIds: source == null
        ? requested
        : [
            ...source.accountIds.where(ids.contains),
            ...requested.where((id) => !source.includesAccount(id)),
          ],
    groups: groups,
    accountGroupIds: assignments,
    sortOrder: sortOrder,
    version: version,
  );
}
