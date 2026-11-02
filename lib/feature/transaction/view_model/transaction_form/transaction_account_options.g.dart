// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_account_options.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(transactionAccountOptions)
final transactionAccountOptionsProvider = TransactionAccountOptionsProvider._();

final class TransactionAccountOptionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<TransactionAccountOptions>,
          AsyncValue<TransactionAccountOptions>,
          AsyncValue<TransactionAccountOptions>
        >
    with $Provider<AsyncValue<TransactionAccountOptions>> {
  TransactionAccountOptionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transactionAccountOptionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transactionAccountOptionsHash();

  @$internal
  @override
  $ProviderElement<AsyncValue<TransactionAccountOptions>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<TransactionAccountOptions> create(Ref ref) {
    return transactionAccountOptions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<TransactionAccountOptions> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<AsyncValue<TransactionAccountOptions>>(value),
    );
  }
}

String _$transactionAccountOptionsHash() =>
    r'f0c02a7a16fc827700f45ba5d768b28434e05a4f';
