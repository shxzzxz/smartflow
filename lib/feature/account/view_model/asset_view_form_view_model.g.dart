// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_view_form_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AssetViewFormViewModel)
final assetViewFormViewModelProvider = AssetViewFormViewModelFamily._();

final class AssetViewFormViewModelProvider
    extends $AsyncNotifierProvider<AssetViewFormViewModel, AssetViewFormState> {
  AssetViewFormViewModelProvider._({
    required AssetViewFormViewModelFamily super.from,
    required (String?, AssetView?) super.argument,
  }) : super(
         retry: null,
         name: r'assetViewFormViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$assetViewFormViewModelHash();

  @override
  String toString() {
    return r'assetViewFormViewModelProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  AssetViewFormViewModel create() => AssetViewFormViewModel();

  @override
  bool operator ==(Object other) {
    return other is AssetViewFormViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$assetViewFormViewModelHash() =>
    r'3f780c21daf042c9c52de78dd1b781a0c6235199';

final class AssetViewFormViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          AssetViewFormViewModel,
          AsyncValue<AssetViewFormState>,
          AssetViewFormState,
          FutureOr<AssetViewFormState>,
          (String?, AssetView?)
        > {
  AssetViewFormViewModelFamily._()
    : super(
        retry: null,
        name: r'assetViewFormViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AssetViewFormViewModelProvider call(String? viewId, AssetView? copyFrom) =>
      AssetViewFormViewModelProvider._(
        argument: (viewId, copyFrom),
        from: this,
      );

  @override
  String toString() => r'assetViewFormViewModelProvider';
}

abstract class _$AssetViewFormViewModel
    extends $AsyncNotifier<AssetViewFormState> {
  late final _$args = ref.$arg as (String?, AssetView?);
  String? get viewId => _$args.$1;
  AssetView? get copyFrom => _$args.$2;

  FutureOr<AssetViewFormState> build(String? viewId, AssetView? copyFrom);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<AssetViewFormState>, AssetViewFormState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AssetViewFormState>, AssetViewFormState>,
              AsyncValue<AssetViewFormState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}

@ProviderFor(assetViewFormPage)
final assetViewFormPageProvider = AssetViewFormPageFamily._();

final class AssetViewFormPageProvider
    extends
        $FunctionalProvider<
          AsyncValue<AssetViewFormPageState>,
          AsyncValue<AssetViewFormPageState>,
          AsyncValue<AssetViewFormPageState>
        >
    with $Provider<AsyncValue<AssetViewFormPageState>> {
  AssetViewFormPageProvider._({
    required AssetViewFormPageFamily super.from,
    required (String?, AssetView?) super.argument,
  }) : super(
         retry: null,
         name: r'assetViewFormPageProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$assetViewFormPageHash();

  @override
  String toString() {
    return r'assetViewFormPageProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<AsyncValue<AssetViewFormPageState>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<AssetViewFormPageState> create(Ref ref) {
    final argument = this.argument as (String?, AssetView?);
    return assetViewFormPage(ref, argument.$1, argument.$2);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<AssetViewFormPageState> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<AssetViewFormPageState>>(
        value,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AssetViewFormPageProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$assetViewFormPageHash() => r'4bd70ba1948009ebb214458d7434435ed03441e9';

final class AssetViewFormPageFamily extends $Family
    with
        $FunctionalFamilyOverride<
          AsyncValue<AssetViewFormPageState>,
          (String?, AssetView?)
        > {
  AssetViewFormPageFamily._()
    : super(
        retry: null,
        name: r'assetViewFormPageProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AssetViewFormPageProvider call(String? viewId, AssetView? copyFrom) =>
      AssetViewFormPageProvider._(argument: (viewId, copyFrom), from: this);

  @override
  String toString() => r'assetViewFormPageProvider';
}
