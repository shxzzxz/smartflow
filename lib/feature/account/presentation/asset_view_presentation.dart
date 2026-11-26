import '../../../application/analytics/analytics_query_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../view_model/account_view.dart';
import 'account_section_presentation.dart';

enum AssetAccountFilter {
  all('全部', null),
  asset('资产', AccountType.asset),
  liability('负债', AccountType.liability);

  const AssetAccountFilter(this.label, this.accountType);
  final String label;
  final AccountType? accountType;
  bool matches(AccountView account) =>
      accountType == null || account.accountType == accountType;
}

class AssetViewLayoutPresentation {
  const AssetViewLayoutPresentation({required this.sections});
  final List<AccountSectionPresentation> sections;
  bool get isEmpty => sections.isEmpty;
}

AssetViewLayoutPresentation buildAssetViewLayout(
  AssetView view,
  List<AccountView> accounts,
  AssetAccountFilter filter,
) => AssetViewLayoutPresentation(
  sections: List.unmodifiable(
    buildActiveAccountSections(
      accounts
          .where((account) => !account.isArchived && filter.matches(account))
          .toList(),
      view,
      includeEmptyGroups: false,
    ),
  ),
);

/// Reorders a displayed subset while keeping hidden items in their original slots.
List<String> mergeVisibleOrder(List<String> allIds, List<String> visibleOrder) {
  final visible = visibleOrder.toSet();
  final iterator = visibleOrder.iterator;
  return [
    for (final id in allIds)
      if (visible.contains(id))
        (iterator.moveNext() ? iterator.current : id)
      else
        id,
  ];
}

String assetSectionCollapseKey(AssetView view, String groupId) =>
    view.isBuiltin ? groupId : '${view.id}/$groupId';
