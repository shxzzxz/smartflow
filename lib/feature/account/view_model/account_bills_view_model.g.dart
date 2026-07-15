// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_bills_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountBillsViewModel)
final accountBillsViewModelProvider = AccountBillsViewModelFamily._();

final class AccountBillsViewModelProvider
    extends
        $FunctionalProvider<
          AccountBillsPageState,
          AccountBillsPageState,
          AccountBillsPageState
        >
    with $Provider<AccountBillsPageState> {
  AccountBillsViewModelProvider._({
    required AccountBillsViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountBillsViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountBillsViewModelHash();

  @override
  String toString() {
    return r'accountBillsViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<AccountBillsPageState> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountBillsPageState create(Ref ref) {
    final argument = this.argument as String;
    return accountBillsViewModel(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountBillsPageState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountBillsPageState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountBillsViewModelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountBillsViewModelHash() =>
    r'38ef2b73d2b64673cf8b69c96bd5b1e1474bf268';

final class AccountBillsViewModelFamily extends $Family
    with $FunctionalFamilyOverride<AccountBillsPageState, String> {
  AccountBillsViewModelFamily._()
    : super(
        retry: null,
        name: r'accountBillsViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountBillsViewModelProvider call(String accountId) =>
      AccountBillsViewModelProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountBillsViewModelProvider';
}
