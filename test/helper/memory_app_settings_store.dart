import 'package:smartflow/application/shared/app_settings_store.dart';

final class MemoryAppSettingsStore implements AppSettingsStore {
  const MemoryAppSettingsStore([this.settings = const AppSettings()]);

  final AppSettings settings;

  @override
  Future<AppSettings> read() async => settings;

  @override
  Future<void> save(AppSettings settings) async {}
}
