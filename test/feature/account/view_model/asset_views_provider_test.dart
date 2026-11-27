import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/analytics/analytics_query_api.dart';
import 'package:smartflow/feature/account/view_model/asset_views_provider.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

import '../../../helper/asset_view_dependencies.dart';

void main() {
  const viewId = 'daily-view';
  late FakeAssetViewQueryService queries;
  late _Preferences preferences;
  late ProviderContainer container;

  setUp(() async {
    queries = FakeAssetViewQueryService(
      views: [
        AssetView(id: AssetView.defaultId, name: AssetView.defaultName),
        AssetView(id: viewId, name: '日常资金', accountIds: ['account']),
      ],
    );
    preferences = _Preferences();
    container = ProviderContainer(
      overrides: [
        assetViewQueryServiceProvider.overrideWithValue(queries),
        assetViewPreferencesStoreProvider.overrideWithValue(preferences),
      ],
    );
    await container.read(assetViewSelectionViewModelProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await queries.close();
  });

  test('selection changes only after the preference write succeeds', () async {
    final started = Completer<void>();
    final finished = Completer<void>();
    preferences.beforeSave = () {
      started.complete();
      return finished.future;
    };
    final selecting = container
        .read(assetViewSelectionViewModelProvider.notifier)
        .selectView(viewId);
    await started.future;
    final selectionDuringSave = container
        .read(assetViewSelectionViewModelProvider)
        .requireValue;
    final preferenceDuringSave = preferences.selected;
    finished.complete();

    expect(await selecting, isA<UiActionSuccess<void>>());
    expect(selectionDuringSave, AssetView.defaultId);
    expect(preferenceDuringSave, AssetView.defaultId);
    expect(preferences.selected, viewId);
    expect(
      container.read(assetViewSelectionViewModelProvider).requireValue,
      viewId,
    );
  });

  test(
    'failed selection keeps the previous choice and can be retried',
    () async {
      preferences.beforeSave = () async {
        if (preferences.saveAttempts == 1) {
          throw Exception('Transient preferences failure');
        }
      };
      final notifier = container.read(
        assetViewSelectionViewModelProvider.notifier,
      );

      expect(await notifier.selectView(viewId), isA<UiActionFailure<void>>());
      final selectionAfterFailure = container
          .read(assetViewSelectionViewModelProvider)
          .requireValue;
      expect(await notifier.selectView(viewId), isA<UiActionSuccess<void>>());
      expect(selectionAfterFailure, AssetView.defaultId);
      expect(preferences.selected, viewId);
      expect(preferences.saveAttempts, 2);
      expect(
        container.read(assetViewSelectionViewModelProvider).requireValue,
        viewId,
      );

      expect(await notifier.selectView(viewId), isA<UiActionSuccess<void>>());
      expect(preferences.saveAttempts, 2);
    },
  );
}

class _Preferences extends MemoryAssetViewPreferences {
  _Preferences() : super(AssetView.defaultId);

  int saveAttempts = 0;
  Future<void> Function()? beforeSave;

  @override
  Future<void> saveSelectedViewId(String id) async {
    saveAttempts++;
    await beforeSave?.call();
    await super.saveSelectedViewId(id);
  }
}
