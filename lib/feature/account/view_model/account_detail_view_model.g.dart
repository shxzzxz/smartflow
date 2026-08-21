// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_detail_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AccountDetailViewModel)
final accountDetailViewModelProvider = AccountDetailViewModelFamily._();

final class AccountDetailViewModelProvider
    extends $NotifierProvider<AccountDetailViewModel, AccountDetailPageState> {
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
  AccountDetailViewModel create() => AccountDetailViewModel();

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
    r'a2300c466bccda9e42bda3d9e70c8074396df201';

final class AccountDetailViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          AccountDetailViewModel,
          AccountDetailPageState,
          AccountDetailPageState,
          AccountDetailPageState,
          String
        > {
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

abstract class _$AccountDetailViewModel
    extends $Notifier<AccountDetailPageState> {
  late final _$args = ref.$arg as String;
  String get accountId => _$args;

  AccountDetailPageState build(String accountId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AccountDetailPageState, AccountDetailPageState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AccountDetailPageState, AccountDetailPageState>,
              AccountDetailPageState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
