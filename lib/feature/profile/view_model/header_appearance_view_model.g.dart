// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'header_appearance_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HeaderAppearanceViewModel)
final headerAppearanceViewModelProvider = HeaderAppearanceViewModelProvider._();

final class HeaderAppearanceViewModelProvider
    extends
        $AsyncNotifierProvider<
          HeaderAppearanceViewModel,
          HeaderAppearanceState
        > {
  HeaderAppearanceViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'headerAppearanceViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$headerAppearanceViewModelHash();

  @$internal
  @override
  HeaderAppearanceViewModel create() => HeaderAppearanceViewModel();
}

String _$headerAppearanceViewModelHash() =>
    r'622396de0a36d73519dcf18ef1984c7ebbfe4e97';

abstract class _$HeaderAppearanceViewModel
    extends $AsyncNotifier<HeaderAppearanceState> {
  FutureOr<HeaderAppearanceState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<HeaderAppearanceState>, HeaderAppearanceState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<HeaderAppearanceState>,
                HeaderAppearanceState
              >,
              AsyncValue<HeaderAppearanceState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
