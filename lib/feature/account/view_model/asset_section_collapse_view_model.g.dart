// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_section_collapse_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AssetSectionCollapseViewModel)
final assetSectionCollapseViewModelProvider =
    AssetSectionCollapseViewModelProvider._();

final class AssetSectionCollapseViewModelProvider
    extends $AsyncNotifierProvider<AssetSectionCollapseViewModel, Set<String>> {
  AssetSectionCollapseViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'assetSectionCollapseViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$assetSectionCollapseViewModelHash();

  @$internal
  @override
  AssetSectionCollapseViewModel create() => AssetSectionCollapseViewModel();
}

String _$assetSectionCollapseViewModelHash() =>
    r'7ccfede1232065e1778ecead2e979a06bf097827';

abstract class _$AssetSectionCollapseViewModel
    extends $AsyncNotifier<Set<String>> {
  FutureOr<Set<String>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Set<String>>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Set<String>>, Set<String>>,
              AsyncValue<Set<String>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
