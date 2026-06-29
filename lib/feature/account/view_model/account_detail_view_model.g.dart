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
    r'8add2a40ea966dac16fada62c27aeff68bb45e3e';

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

@ProviderFor(creditAccountOverview)
final creditAccountOverviewProvider = CreditAccountOverviewFamily._();

final class CreditAccountOverviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<CreditAccountOverviewReadModel?>,
          CreditAccountOverviewReadModel?,
          FutureOr<CreditAccountOverviewReadModel?>
        >
    with
        $FutureModifier<CreditAccountOverviewReadModel?>,
        $FutureProvider<CreditAccountOverviewReadModel?> {
  CreditAccountOverviewProvider._({
    required CreditAccountOverviewFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'creditAccountOverviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$creditAccountOverviewHash();

  @override
  String toString() {
    return r'creditAccountOverviewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<CreditAccountOverviewReadModel?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CreditAccountOverviewReadModel?> create(Ref ref) {
    final argument = this.argument as String;
    return creditAccountOverview(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CreditAccountOverviewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$creditAccountOverviewHash() =>
    r'264c9c387fc384043fb532db0bc2598651e17fa2';

final class CreditAccountOverviewFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<CreditAccountOverviewReadModel?>,
          String
        > {
  CreditAccountOverviewFamily._()
    : super(
        retry: null,
        name: r'creditAccountOverviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CreditAccountOverviewProvider call(String accountId) =>
      CreditAccountOverviewProvider._(argument: accountId, from: this);

  @override
  String toString() => r'creditAccountOverviewProvider';
}
