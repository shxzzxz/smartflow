// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_transactions_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountTransactionsViewModel)
final accountTransactionsViewModelProvider =
    AccountTransactionsViewModelFamily._();

final class AccountTransactionsViewModelProvider
    extends
        $FunctionalProvider<
          AccountTransactionsState,
          AccountTransactionsState,
          AccountTransactionsState
        >
    with $Provider<AccountTransactionsState> {
  AccountTransactionsViewModelProvider._({
    required AccountTransactionsViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountTransactionsViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountTransactionsViewModelHash();

  @override
  String toString() {
    return r'accountTransactionsViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<AccountTransactionsState> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountTransactionsState create(Ref ref) {
    final argument = this.argument as String;
    return accountTransactionsViewModel(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountTransactionsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountTransactionsState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountTransactionsViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountTransactionsViewModelHash() =>
    r'29ddcff4d89f37e0d033587b983d3e7c759a2c3b';

final class AccountTransactionsViewModelFamily extends $Family
    with $FunctionalFamilyOverride<AccountTransactionsState, String> {
  AccountTransactionsViewModelFamily._()
    : super(
        retry: null,
        name: r'accountTransactionsViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountTransactionsViewModelProvider call(String accountId) =>
      AccountTransactionsViewModelProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountTransactionsViewModelProvider';
}
