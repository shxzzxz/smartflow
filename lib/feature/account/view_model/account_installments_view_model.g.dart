// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_installments_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountInstallmentsViewModel)
final accountInstallmentsViewModelProvider =
    AccountInstallmentsViewModelFamily._();

final class AccountInstallmentsViewModelProvider
    extends
        $FunctionalProvider<
          AsyncValue<AccountInstallmentsState?>,
          AsyncValue<AccountInstallmentsState?>,
          AsyncValue<AccountInstallmentsState?>
        >
    with $Provider<AsyncValue<AccountInstallmentsState?>> {
  AccountInstallmentsViewModelProvider._({
    required AccountInstallmentsViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountInstallmentsViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountInstallmentsViewModelHash();

  @override
  String toString() {
    return r'accountInstallmentsViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<AsyncValue<AccountInstallmentsState?>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<AccountInstallmentsState?> create(Ref ref) {
    final argument = this.argument as String;
    return accountInstallmentsViewModel(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<AccountInstallmentsState?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<AsyncValue<AccountInstallmentsState?>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountInstallmentsViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountInstallmentsViewModelHash() =>
    r'76486a0fe81e36131f9b21128c5045c17b97ccfc';

final class AccountInstallmentsViewModelFamily extends $Family
    with
        $FunctionalFamilyOverride<
          AsyncValue<AccountInstallmentsState?>,
          String
        > {
  AccountInstallmentsViewModelFamily._()
    : super(
        retry: null,
        name: r'accountInstallmentsViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountInstallmentsViewModelProvider call(String accountId) =>
      AccountInstallmentsViewModelProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountInstallmentsViewModelProvider';
}
