// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_page_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(assetViewStatistics)
final assetViewStatisticsProvider = AssetViewStatisticsFamily._();

final class AssetViewStatisticsProvider
    extends
        $FunctionalProvider<
          AsyncValue<AssetViewStatistics>,
          AssetViewStatistics,
          Stream<AssetViewStatistics>
        >
    with
        $FutureModifier<AssetViewStatistics>,
        $StreamProvider<AssetViewStatistics> {
  AssetViewStatisticsProvider._({
    required AssetViewStatisticsFamily super.from,
    required AssetView super.argument,
  }) : super(
         retry: null,
         name: r'assetViewStatisticsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$assetViewStatisticsHash();

  @override
  String toString() {
    return r'assetViewStatisticsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<AssetViewStatistics> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<AssetViewStatistics> create(Ref ref) {
    final argument = this.argument as AssetView;
    return assetViewStatistics(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AssetViewStatisticsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$assetViewStatisticsHash() =>
    r'300c906ae6d6f032ad19c68472708cfca036242f';

final class AssetViewStatisticsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<AssetViewStatistics>, AssetView> {
  AssetViewStatisticsFamily._()
    : super(
        retry: null,
        name: r'assetViewStatisticsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AssetViewStatisticsProvider call(AssetView view) =>
      AssetViewStatisticsProvider._(argument: view, from: this);

  @override
  String toString() => r'assetViewStatisticsProvider';
}

@ProviderFor(assetViewContent)
final assetViewContentProvider = AssetViewContentFamily._();

final class AssetViewContentProvider
    extends
        $FunctionalProvider<
          AsyncValue<AssetViewContentState>,
          AsyncValue<AssetViewContentState>,
          AsyncValue<AssetViewContentState>
        >
    with $Provider<AsyncValue<AssetViewContentState>> {
  AssetViewContentProvider._({
    required AssetViewContentFamily super.from,
    required (AssetView, AssetAccountFilter) super.argument,
  }) : super(
         retry: null,
         name: r'assetViewContentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$assetViewContentHash();

  @override
  String toString() {
    return r'assetViewContentProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<AsyncValue<AssetViewContentState>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<AssetViewContentState> create(Ref ref) {
    final argument = this.argument as (AssetView, AssetAccountFilter);
    return assetViewContent(ref, argument.$1, argument.$2);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<AssetViewContentState> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<AssetViewContentState>>(
        value,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AssetViewContentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$assetViewContentHash() => r'b93d05bec473511acd87ac5c36fa6c6ff33b8413';

final class AssetViewContentFamily extends $Family
    with
        $FunctionalFamilyOverride<
          AsyncValue<AssetViewContentState>,
          (AssetView, AssetAccountFilter)
        > {
  AssetViewContentFamily._()
    : super(
        retry: null,
        name: r'assetViewContentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AssetViewContentProvider call(AssetView view, AssetAccountFilter filter) =>
      AssetViewContentProvider._(argument: (view, filter), from: this);

  @override
  String toString() => r'assetViewContentProvider';
}

@ProviderFor(assetPageState)
final assetPageStateProvider = AssetPageStateProvider._();

final class AssetPageStateProvider
    extends
        $FunctionalProvider<
          AsyncValue<AssetPageState>,
          AsyncValue<AssetPageState>,
          AsyncValue<AssetPageState>
        >
    with $Provider<AsyncValue<AssetPageState>> {
  AssetPageStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'assetPageStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$assetPageStateHash();

  @$internal
  @override
  $ProviderElement<AsyncValue<AssetPageState>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<AssetPageState> create(Ref ref) {
    return assetPageState(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<AssetPageState> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<AssetPageState>>(value),
    );
  }
}

String _$assetPageStateHash() => r'07163214f1a997fb5970b6fe23fd44057dbb7d93';

@ProviderFor(AssetPageViewModel)
final assetPageViewModelProvider = AssetPageViewModelProvider._();

final class AssetPageViewModelProvider
    extends $NotifierProvider<AssetPageViewModel, AssetAccountFilter> {
  AssetPageViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'assetPageViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$assetPageViewModelHash();

  @$internal
  @override
  AssetPageViewModel create() => AssetPageViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AssetAccountFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AssetAccountFilter>(value),
    );
  }
}

String _$assetPageViewModelHash() =>
    r'8d02226ce1c54daa738cc54631888057e319cef7';

abstract class _$AssetPageViewModel extends $Notifier<AssetAccountFilter> {
  AssetAccountFilter build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AssetAccountFilter, AssetAccountFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AssetAccountFilter, AssetAccountFilter>,
              AssetAccountFilter,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(AssetViewManagementViewModel)
final assetViewManagementViewModelProvider =
    AssetViewManagementViewModelProvider._();

final class AssetViewManagementViewModelProvider
    extends $NotifierProvider<AssetViewManagementViewModel, bool> {
  AssetViewManagementViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'assetViewManagementViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$assetViewManagementViewModelHash();

  @$internal
  @override
  AssetViewManagementViewModel create() => AssetViewManagementViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$assetViewManagementViewModelHash() =>
    r'81b0dd9a7638161c72ae9b5f23c41987f50d4fd9';

abstract class _$AssetViewManagementViewModel extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
