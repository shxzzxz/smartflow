import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/analytics/analytics_query_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../domain/analytics/valobj/analytics_error_code.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';

part 'asset_views_provider.g.dart';

final _logger = Logger('feature.asset_view.selection');

@riverpod
Stream<List<AssetView>> assetViews(Ref ref) =>
    ref.watch(assetViewQueryServiceProvider).watchViews();

@riverpod
AsyncValue<AssetView> selectedAssetView(Ref ref) {
  final views = ref.watch(assetViewsProvider);
  final selected = ref.watch(assetViewSelectionViewModelProvider);
  if (views.hasError) return AsyncError(views.error!, views.stackTrace!);
  if (selected.hasError) {
    return AsyncError(selected.error!, selected.stackTrace!);
  }
  if (!views.hasValue || !selected.hasValue) return const AsyncLoading();
  final view =
      views.requireValue
          .where((view) => view.id == selected.value)
          .firstOrNull ??
      views.requireValue.where((view) => view.isBuiltin).firstOrNull;
  return view == null ? const AsyncLoading() : AsyncData(view);
}

@riverpod
AsyncValue<List<AssetViewGroup>> assetViewGroups(Ref ref, String viewId) =>
    ref.watch(assetViewsProvider).whenData((views) {
      final view = views.where((view) => view.id == viewId).firstOrNull;
      if (view == null) {
        throw BusinessException(AnalyticsErrorCode.viewNotFound);
      }
      return view.groups;
    });

@Riverpod(keepAlive: true)
class AssetViewSelectionViewModel extends _$AssetViewSelectionViewModel {
  @override
  Future<String?> build() =>
      ref.watch(assetViewPreferencesStoreProvider).readSelectedViewId();

  Future<UiActionOutcome<void>> selectView(String id) => guardUiAction(
    _logger,
    'Select asset view',
    () async {
      if (await ref.read(assetViewQueryServiceProvider).findView(id) == null) {
        throw BusinessException(AnalyticsErrorCode.viewNotFound);
      }
      if (state.hasValue && state.value == id) return;
      state = AsyncData(id);
      await ref.read(assetViewPreferencesStoreProvider).saveSelectedViewId(id);
    },
  );
}
