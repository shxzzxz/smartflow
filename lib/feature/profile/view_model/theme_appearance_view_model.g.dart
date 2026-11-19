// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_appearance_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ThemeAppearanceViewModel)
final themeAppearanceViewModelProvider = ThemeAppearanceViewModelProvider._();

final class ThemeAppearanceViewModelProvider
    extends
        $AsyncNotifierProvider<ThemeAppearanceViewModel, ThemeAppearanceState> {
  ThemeAppearanceViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeAppearanceViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeAppearanceViewModelHash();

  @$internal
  @override
  ThemeAppearanceViewModel create() => ThemeAppearanceViewModel();
}

String _$themeAppearanceViewModelHash() =>
    r'00ebe2a586b4002881569e6de3995f8ac476d0ae';

abstract class _$ThemeAppearanceViewModel
    extends $AsyncNotifier<ThemeAppearanceState> {
  FutureOr<ThemeAppearanceState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<ThemeAppearanceState>, ThemeAppearanceState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<ThemeAppearanceState>,
                ThemeAppearanceState
              >,
              AsyncValue<ThemeAppearanceState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
