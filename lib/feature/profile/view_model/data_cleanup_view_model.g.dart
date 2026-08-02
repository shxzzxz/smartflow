// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_cleanup_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DataCleanupViewModel)
final dataCleanupViewModelProvider = DataCleanupViewModelProvider._();

final class DataCleanupViewModelProvider
    extends $NotifierProvider<DataCleanupViewModel, DataCleanupState> {
  DataCleanupViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dataCleanupViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dataCleanupViewModelHash();

  @$internal
  @override
  DataCleanupViewModel create() => DataCleanupViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DataCleanupState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DataCleanupState>(value),
    );
  }
}

String _$dataCleanupViewModelHash() =>
    r'd09585a77b72f8a6b3fbdc2e92ba3b1f9952e406';

abstract class _$DataCleanupViewModel extends $Notifier<DataCleanupState> {
  DataCleanupState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<DataCleanupState, DataCleanupState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DataCleanupState, DataCleanupState>,
              DataCleanupState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(dataCleanupPreview)
final dataCleanupPreviewProvider = DataCleanupPreviewProvider._();

final class DataCleanupPreviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<TransactionCleanupPreview>,
          TransactionCleanupPreview,
          Stream<TransactionCleanupPreview>
        >
    with
        $FutureModifier<TransactionCleanupPreview>,
        $StreamProvider<TransactionCleanupPreview> {
  DataCleanupPreviewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dataCleanupPreviewProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dataCleanupPreviewHash();

  @$internal
  @override
  $StreamProviderElement<TransactionCleanupPreview> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<TransactionCleanupPreview> create(Ref ref) {
    return dataCleanupPreview(ref);
  }
}

String _$dataCleanupPreviewHash() =>
    r'69e0269580395e40684bbd633dfdb9494bd85bb1';
