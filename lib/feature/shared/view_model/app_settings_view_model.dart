import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/shared/app_settings_store.dart';

part 'app_settings_view_model.g.dart';

@Riverpod(keepAlive: true)
class AppSettingsViewModel extends _$AppSettingsViewModel {
  @override
  Future<AppSettings> build() {
    return ref.watch(appSettingsStoreProvider).read();
  }

  Future<void> setShowAddTransactionFab(bool value) {
    return _save((settings) => settings.copyWith(showAddTransactionFab: value));
  }

  Future<void> setShowBottomNavLabels(bool value) {
    return _save((settings) => settings.copyWith(showBottomNavLabels: value));
  }

  Future<void> setPullToCreateSensitivity(PullToCreateSensitivity value) {
    return _save(
      (settings) => settings.copyWith(pullToCreateSensitivity: value),
    );
  }

  Future<void> _save(AppSettings Function(AppSettings settings) change) async {
    final next = change(state.value ?? const AppSettings());
    state = AsyncData(next);
    await ref.read(appSettingsStoreProvider).save(next);
  }
}
