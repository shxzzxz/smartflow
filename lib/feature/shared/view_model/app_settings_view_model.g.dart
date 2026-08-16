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
    r'a0868fa4a8c207cf4823f94f572e87dddf990b68';

abstract class _$AppSettingsViewModel extends $AsyncNotifier<AppSettings> {
  FutureOr<AppSettings> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<AppSettings>, AppSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AppSettings>, AppSettings>,
              AsyncValue<AppSettings>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
