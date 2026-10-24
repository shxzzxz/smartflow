// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AppSettingsViewModel)
final appSettingsViewModelProvider = AppSettingsViewModelProvider._();

final class AppSettingsViewModelProvider
    extends $AsyncNotifierProvider<AppSettingsViewModel, AppSettings> {
  AppSettingsViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appSettingsViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appSettingsViewModelHash();

  @$internal
  @override
  AppSettingsViewModel create() => AppSettingsViewModel();
}

String _$appSettingsViewModelHash() =>
    r'e08b65d07663c49a84bae20c58dc78e65b0de0e8';

abstract class _$AppSettingsViewModel extends $AsyncNotifier<AppSettings> {
  FutureOr<AppSettings> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<AppSettings>, AppSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AppSettings>, AppSettings>,
              AsyncValue<AppSettings>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
