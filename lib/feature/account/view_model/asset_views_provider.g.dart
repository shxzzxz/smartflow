// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_views_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(assetViews)
final assetViewsProvider = AssetViewsProvider._();

final class AssetViewsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AssetView>>,
          List<AssetView>,
          Stream<List<AssetView>>
        >
    with $FutureModifier<List<AssetView>>, $StreamProvider<List<AssetView>> {
  AssetViewsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'assetViewsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$assetViewsHash();

  @$internal
  @override
  $StreamProviderElement<List<AssetView>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<AssetView>> create(Ref ref) {
    return assetViews(ref);
  }
}

String _$assetViewsHash() => r'6e3c2c57b6a3a5348737e6ea2574b11690ac405d';

@ProviderFor(selectedAssetView)
final selectedAssetViewProvider = SelectedAssetViewProvider._();

final class SelectedAssetViewProvider
    extends
        $FunctionalProvider<
          AsyncValue<AssetView>,
          AsyncValue<AssetView>,
          AsyncValue<AssetView>
        >
    with $Provider<AsyncValue<AssetView>> {
  SelectedAssetViewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedAssetViewProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedAssetViewHash();

  @$internal
  @override
  $ProviderElement<AsyncValue<AssetView>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<AssetView> create(Ref ref) {
    return selectedAssetView(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<AssetView> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<AssetView>>(value),
    );
  }
}

String _$selectedAssetViewHash() => r'533a362a89bf6367a81adc1399082f9eb860a76e';

@ProviderFor(assetViewGroups)
final assetViewGroupsProvider = AssetViewGroupsFamily._();

final class AssetViewGroupsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AssetViewGroup>>,
          AsyncValue<List<AssetViewGroup>>,
          AsyncValue<List<AssetViewGroup>>
        >
    with $Provider<AsyncValue<List<AssetViewGroup>>> {
  AssetViewGroupsProvider._({
    required AssetViewGroupsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'assetViewGroupsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$assetViewGroupsHash();

  @override
  String toString() {
    return r'assetViewGroupsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<AsyncValue<List<AssetViewGroup>>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<List<AssetViewGroup>> create(Ref ref) {
    final argument = this.argument as String;
    return assetViewGroups(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<List<AssetViewGroup>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<List<AssetViewGroup>>>(
        value,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AssetViewGroupsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$assetViewGroupsHash() => r'373139db8ff78563e58950d8c1d923fe9cd865d3';

final class AssetViewGroupsFamily extends $Family
    with $FunctionalFamilyOverride<AsyncValue<List<AssetViewGroup>>, String> {
  AssetViewGroupsFamily._()
    : super(
        retry: null,
        name: r'assetViewGroupsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AssetViewGroupsProvider call(String viewId) =>
      AssetViewGroupsProvider._(argument: viewId, from: this);

  @override
  String toString() => r'assetViewGroupsProvider';
}

@ProviderFor(AssetViewSelectionViewModel)
final assetViewSelectionViewModelProvider =
    AssetViewSelectionViewModelProvider._();

final class AssetViewSelectionViewModelProvider
    extends $AsyncNotifierProvider<AssetViewSelectionViewModel, String?> {
  AssetViewSelectionViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'assetViewSelectionViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$assetViewSelectionViewModelHash();

  @$internal
  @override
  AssetViewSelectionViewModel create() => AssetViewSelectionViewModel();
}

String _$assetViewSelectionViewModelHash() =>
    r'c8749d605cb6fbbab27cfb77baed6f49a466e2bc';

abstract class _$AssetViewSelectionViewModel extends $AsyncNotifier<String?> {
  FutureOr<String?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, String?>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
