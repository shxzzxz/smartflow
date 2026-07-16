// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_bills_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AccountBillsViewModel)
final accountBillsViewModelProvider = AccountBillsViewModelFamily._();

final class AccountBillsViewModelProvider
    extends $NotifierProvider<AccountBillsViewModel, AccountBillsPageState> {
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
  AccountBillsViewModel create() => AccountBillsViewModel();

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
    r'6e79e05de9a84dffffd7f1d8876dc69f98681663';

final class AccountBillsViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          AccountBillsViewModel,
          AccountBillsPageState,
          AccountBillsPageState,
          AccountBillsPageState,
          String
        > {
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

abstract class _$AccountBillsViewModel
    extends $Notifier<AccountBillsPageState> {
  late final _$args = ref.$arg as String;
  String get accountId => _$args;

  AccountBillsPageState build(String accountId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AccountBillsPageState, AccountBillsPageState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AccountBillsPageState, AccountBillsPageState>,
              AccountBillsPageState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
