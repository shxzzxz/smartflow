import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/analytics/analytics_query_api.dart';
import '../../shared/provider/current_date_time_provider.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/account_section_presentation.dart';
import '../presentation/asset_view_presentation.dart';
import 'account_view.dart';
import 'account_views_provider.dart';
import 'account_organization_view_model.dart';
import 'asset_views_provider.dart';

export 'asset_views_provider.dart';

part 'asset_page_view_model.g.dart';

final _logger = Logger('feature.asset_view');

@riverpod
Stream<AssetViewStatistics> assetViewStatistics(Ref ref, AssetView view) => ref
    .watch(assetViewQueryServiceProvider)
    .watchStatistics(view, ref.watch(currentDateTimeProvider));

class AssetViewContentState {
  const AssetViewContentState({
    required this.view,
    required this.accounts,
    required this.archivedAccounts,
    required this.statistics,
    required this.layout,
  });
  final AssetView view;
  final List<AccountView> accounts;
  List<AssetViewGroup> get groups => view.groups;
  final List<AccountView> archivedAccounts;
  final AssetViewStatistics statistics;
  final AssetViewLayoutPresentation layout;
}

@riverpod
AsyncValue<AssetViewContentState> assetViewContent(
  Ref ref,
  AssetView view,
  AssetAccountFilter filter,
) {
  final accounts = ref.watch(accountViewsProvider);
  final archived = ref.watch(archivedAccountViewsProvider);
  final statistics = ref.watch(assetViewStatisticsProvider(view));
  for (final value in <AsyncValue<Object?>>[accounts, archived, statistics]) {
    if (value.hasError) return AsyncError(value.error!, value.stackTrace!);
  }
  if (!accounts.hasValue || !archived.hasValue || !statistics.hasValue) {
    return const AsyncLoading();
  }
  return AsyncData(
    AssetViewContentState(
      view: view,
      accounts: accounts.requireValue
          .where((account) => view.includesAccount(account.id))
          .toList(),
      statistics: statistics.requireValue,
      archivedAccounts: archived.requireValue
          .where(
            (account) =>
                view.includesAccount(account.id) && filter.matches(account),
          )
          .toList(),
      layout: buildAssetViewLayout(view, accounts.requireValue, filter),
    ),
  );
}

class AssetPageState {
  const AssetPageState({required this.views, required this.content});
  final List<AssetView> views;
  final AssetViewContentState content;
}

@riverpod
AsyncValue<AssetPageState> assetPageState(Ref ref) {
  final views = ref.watch(assetViewsProvider);
  final selected = ref.watch(selectedAssetViewProvider);
  if (views.hasError) return AsyncError(views.error!, views.stackTrace!);
  if (selected.hasError) {
    return AsyncError(selected.error!, selected.stackTrace!);
  }
  if (!views.hasValue || views.isLoading || !selected.hasValue) {
    return const AsyncLoading();
  }
  return ref
      .watch(
        assetViewContentProvider(
          selected.requireValue,
          ref.watch(assetPageViewModelProvider),
        ),
      )
      .whenData(
        (content) =>
            AssetPageState(views: views.requireValue, content: content),
      );
}

@riverpod
class AssetPageViewModel extends _$AssetPageViewModel {
  @override
  AssetAccountFilter build() => AssetAccountFilter.all;
  void selectType(AssetAccountFilter filter) => state = filter;

  void retry() {
    ref.invalidate(assetViewsProvider);
    ref.invalidate(assetViewStatisticsProvider);
    ref.invalidate(accountListProvider);
    ref.invalidate(accountsByIdProvider);
    ref.invalidate(creditLiabilityAccountsByAccountIdProvider);
    ref.invalidate(assetViewSelectionViewModelProvider);
  }

  Future<UiActionOutcome<void>> reorderGroups(
    AssetView view,
    List<AccountSectionPresentation> sections,
    int oldIndex,
    int newIndex,
  ) {
    final visible = sections.map((section) => section.id).toList();
    final id = visible.removeAt(oldIndex);
    if (id == 'ungrouped') {
      return Future.value(const UiActionOutcome.success(null));
    }
    visible.insert(newIndex.clamp(0, visible.length), id);
    visible.remove('ungrouped');
    return ref
        .read(accountOrganizationViewModelProvider(view.id).notifier)
        .reorderGroups(
          mergeVisibleOrder(
            view.groups.map((group) => group.id).toList(),
            visible,
          ),
        );
  }

  Future<UiActionOutcome<void>> reorderAccounts(
    AssetView view,
    AccountSectionPresentation section,
    int oldIndex,
    int newIndex,
  ) {
    final order = section.accounts.map((account) => account.id).toList();
    final moved = order.removeAt(oldIndex);
    order.insert(newIndex.clamp(0, order.length), moved);
    final groupId = section.id == 'ungrouped' ? null : section.id;
    final merged = mergeVisibleOrder(view.accountsInGroup(groupId), order);
    return ref
        .read(accountOrganizationViewModelProvider(view.id).notifier)
        .moveAccount(
          accountId: moved,
          targetGroupId: groupId,
          targetAccountIds: merged,
          insertAt: merged.indexOf(moved),
        );
  }
}

@riverpod
class AssetViewManagementViewModel extends _$AssetViewManagementViewModel {
  @override
  bool build() => false;
  Future<UiActionOutcome<void>> deleteView(String id) => _run(
    'Delete asset view',
    () => ref.read(assetViewAppServiceProvider).deleteView(id),
  );
  Future<UiActionOutcome<void>> reorderViews(
    List<AssetView> views,
    int oldIndex,
    int newIndex,
  ) => _run('Reorder asset views', () async {
    final ids = views.map((view) => view.id).toList();
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex.clamp(1, ids.length), moved);
    await ref.read(assetViewAppServiceProvider).reorderViews(ids);
  });
  Future<UiActionOutcome<void>> _run(
    String operation,
    Future<void> Function() action,
  ) async {
    if (state) return const UiActionOutcome.failure(UiError.unknown());
    state = true;
    try {
      return await guardUiAction(_logger, operation, action);
    } finally {
      if (ref.mounted) state = false;
    }
  }
}
