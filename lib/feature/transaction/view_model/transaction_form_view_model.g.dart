// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_form_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TransactionFormViewModel)
final transactionFormViewModelProvider = TransactionFormViewModelProvider._();

final class TransactionFormViewModelProvider
    extends $NotifierProvider<TransactionFormViewModel, TransactionFormState> {
  TransactionFormViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transactionFormViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transactionFormViewModelHash();

  @$internal
  @override
  TransactionFormViewModel create() => TransactionFormViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TransactionFormState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TransactionFormState>(value),
    );
  }
}

String _$transactionFormViewModelHash() =>
    r'196e3b9c9fe6695bfcf3618885ec58dc5865f6a4';

abstract class _$TransactionFormViewModel
    extends $Notifier<TransactionFormState> {
  TransactionFormState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<TransactionFormState, TransactionFormState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TransactionFormState, TransactionFormState>,
              TransactionFormState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
