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

  Money totalFor(AccountType type) {
    return Money(
      minorUnits: accounts.fold(0, (sum, account) {
        return sum +
            (account.accountType == type ? account.balance.minorUnits : 0);
      }),
    );
  }

  Money get netTotal =>
      totalFor(AccountType.asset) - totalFor(AccountType.liability);
}

List<AccountSectionPresentation> buildActiveAccountSections(
  List<AccountView> accounts,
  List<AccountGroup> groups,
) {
  return _buildAccountSections(
    accounts,
    groups,
    includeEmptyGroups: true,
    includeUnknownGroupsAsUngrouped: false,
  );
}

List<AccountSectionPresentation> buildArchivedAccountSections(
  List<AccountView> accounts,
  List<AccountGroup> groups,
) {
  return _buildAccountSections(
    accounts,
    groups,
    includeEmptyGroups: false,
    includeUnknownGroupsAsUngrouped: true,
  );
}

List<AccountSectionPresentation> _buildAccountSections(
  List<AccountView> accounts,
  List<AccountGroup> groups, {
  required bool includeEmptyGroups,
  required bool includeUnknownGroupsAsUngrouped,
}) {
  final sections = <AccountSectionPresentation>[];
  final knownGroupIds = {for (final group in groups) group.id};
  for (final group in groups) {
    final groupedAccounts = [
      for (final account in accounts)
        if (account.groupId == group.id) account,
    ];
    if (includeEmptyGroups || groupedAccounts.isNotEmpty) {
      sections.add(
        AccountSectionPresentation(
          id: group.id,
          title: group.name,
          accounts: groupedAccounts,
        ),
      );
    }
  }

  final ungroupedAccounts = [
    for (final account in accounts)
      if (account.groupId == null ||
          (includeUnknownGroupsAsUngrouped &&
              !knownGroupIds.contains(account.groupId)))
        account,
  ];
  if (ungroupedAccounts.isNotEmpty) {
    sections.add(
      AccountSectionPresentation(
        id: 'ungrouped',
        title: '未分组',
        accounts: ungroupedAccounts,
      ),
    );
  }
  return sections;
}
