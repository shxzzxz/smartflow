// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'navigation_appearance_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(NavigationAppearanceViewModel)
final navigationAppearanceViewModelProvider =
    NavigationAppearanceViewModelProvider._();

final class NavigationAppearanceViewModelProvider
    extends
        $AsyncNotifierProvider<
          NavigationAppearanceViewModel,
          NavigationAppearanceState
        > {
  NavigationAppearanceViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'navigationAppearanceViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$navigationAppearanceViewModelHash();

  @$internal
  @override
  NavigationAppearanceViewModel create() => NavigationAppearanceViewModel();
}

String _$navigationAppearanceViewModelHash() =>
    r'ec2593b9ea05e5eb35b08fdfa91957f17c3fc93e';

abstract class _$NavigationAppearanceViewModel
    extends $AsyncNotifier<NavigationAppearanceState> {
  FutureOr<NavigationAppearanceState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<NavigationAppearanceState>,
              NavigationAppearanceState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<NavigationAppearanceState>,
                NavigationAppearanceState
              >,
              AsyncValue<NavigationAppearanceState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
