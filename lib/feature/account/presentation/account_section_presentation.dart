import '../../../application/analytics/analytics_query_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../view_model/account_view.dart';

class AccountSectionPresentation {
  AccountSectionPresentation({
    required this.id,
    required this.title,
    required List<AccountView> accounts,
  }) : accounts = List.unmodifiable(accounts);

  final String id;
  final String title;
  final List<AccountView> accounts;

  Money totalFor(AccountType type) => Money(
    minorUnits: accounts.fold(
      0,
      (sum, account) =>
          sum + (account.accountType == type ? account.balance.minorUnits : 0),
    ),
  );
  Money get netTotal =>
      totalFor(AccountType.asset) - totalFor(AccountType.liability);
}

List<AccountSectionPresentation> buildActiveAccountSections(
  List<AccountView> accounts,
  AssetView view, {
  bool includeEmptyGroups = true,
}) => _buildAccountSections(accounts, view, includeEmptyGroups);

List<AccountSectionPresentation> buildArchivedAccountSections(
  List<AccountView> accounts,
  AssetView view,
) => _buildAccountSections(accounts, view, false);

List<AccountSectionPresentation> _buildAccountSections(
  List<AccountView> accounts,
  AssetView view,
  bool includeEmptyGroups,
) {
  final byId = {for (final account in accounts) account.id: account};
  final ordered = [
    for (final id in view.accountIds)
      if (byId.containsKey(id)) byId[id]!,
  ];
  final sections = <AccountSectionPresentation>[
    for (final group in view.groups)
      if (includeEmptyGroups ||
          ordered.any((account) => view.groupIdFor(account.id) == group.id))
        AccountSectionPresentation(
          id: group.id,
          title: group.name,
          accounts: ordered
              .where((account) => view.groupIdFor(account.id) == group.id)
              .toList(),
        ),
  ];
  final ungrouped = ordered
      .where((account) => view.groupIdFor(account.id) == null)
      .toList();
  if (ungrouped.isNotEmpty) {
    sections.add(
      AccountSectionPresentation(
        id: 'ungrouped',
        title: '未分组',
        accounts: ungrouped,
      ),
    );
  }
  return sections;
}
