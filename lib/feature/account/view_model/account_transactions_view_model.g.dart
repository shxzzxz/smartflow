// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_transactions_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AccountTransactionPaging)
final accountTransactionPagingProvider = AccountTransactionPagingFamily._();

final class AccountTransactionPagingProvider
    extends $NotifierProvider<AccountTransactionPaging, int> {
  AccountTransactionPagingProvider._({
    required AccountTransactionPagingFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountTransactionPagingProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountTransactionPagingHash();

  @override
  String toString() {
    return r'accountTransactionPagingProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AccountTransactionPaging create() => AccountTransactionPaging();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountTransactionPagingProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountTransactionPagingHash() =>
    r'6dc39cd064b01276dd0022d21b7ba9432a6d899b';

final class AccountTransactionPagingFamily extends $Family
    with $ClassFamilyOverride<AccountTransactionPaging, int, int, int, String> {
  AccountTransactionPagingFamily._()
    : super(
        retry: null,
        name: r'accountTransactionPagingProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountTransactionPagingProvider call(String accountId) =>
      AccountTransactionPagingProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountTransactionPagingProvider';
}

abstract class _$AccountTransactionPaging extends $Notifier<int> {
  late final _$args = ref.$arg as String;
  String get accountId => _$args;

  int build(String accountId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(AccountTransactionsViewModel)
final accountTransactionsViewModelProvider =
    AccountTransactionsViewModelFamily._();

final class AccountTransactionsViewModelProvider
    extends
        $NotifierProvider<
          AccountTransactionsViewModel,
          AccountTransactionsState
        > {
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
  AccountTransactionsViewModel create() => AccountTransactionsViewModel();

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
    r'9577024c1f2adb72b0dd688614a27335afb096eb';

final class AccountTransactionsViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          AccountTransactionsViewModel,
          AccountTransactionsState,
          AccountTransactionsState,
          AccountTransactionsState,
          String
        > {
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

abstract class _$AccountTransactionsViewModel
    extends $Notifier<AccountTransactionsState> {
  late final _$args = ref.$arg as String;
  String get accountId => _$args;

  AccountTransactionsState build(String accountId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AccountTransactionsState, AccountTransactionsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AccountTransactionsState, AccountTransactionsState>,
              AccountTransactionsState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
