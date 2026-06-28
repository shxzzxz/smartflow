// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_detail_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountDetailViewModel)
final accountDetailViewModelProvider = AccountDetailViewModelFamily._();

final class AccountDetailViewModelProvider
    extends
        $FunctionalProvider<
          AccountDetailPageState,
          AccountDetailPageState,
          AccountDetailPageState
        >
    with $Provider<AccountDetailPageState> {
  AccountDetailViewModelProvider._({
    required AccountDetailViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountDetailViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountDetailViewModelHash();

  @override
  String toString() {
    return r'accountDetailViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<AccountDetailPageState> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountDetailPageState create(Ref ref) {
    final argument = this.argument as String;
    return accountDetailViewModel(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountDetailPageState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountDetailPageState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountDetailViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountDetailViewModelHash() =>
    r'83c0b2bda5b6ebe072fc6d57dbf7a8945d9e21a7';

final class AccountDetailViewModelFamily extends $Family
    with $FunctionalFamilyOverride<AccountDetailPageState, String> {
  AccountDetailViewModelFamily._()
    : super(
        retry: null,
        name: r'accountDetailViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountDetailViewModelProvider call(String accountId) =>
      AccountDetailViewModelProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountDetailViewModelProvider';
}
