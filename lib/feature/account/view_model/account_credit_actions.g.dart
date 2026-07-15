// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_credit_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AccountCreditActions)
final accountCreditActionsProvider = AccountCreditActionsFamily._();

final class AccountCreditActionsProvider
    extends $NotifierProvider<AccountCreditActions, void> {
  AccountCreditActionsProvider._({
    required AccountCreditActionsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountCreditActionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountCreditActionsHash();

  @override
  String toString() {
    return r'accountCreditActionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AccountCreditActions create() => AccountCreditActions();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountCreditActionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountCreditActionsHash() =>
    r'bf687e55290dc547f4a97228d5239457e5c62b48';

final class AccountCreditActionsFamily extends $Family
    with $ClassFamilyOverride<AccountCreditActions, void, void, void, String> {
  AccountCreditActionsFamily._()
    : super(
        retry: null,
        name: r'accountCreditActionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountCreditActionsProvider call(String accountId) =>
      AccountCreditActionsProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountCreditActionsProvider';
}

abstract class _$AccountCreditActions extends $Notifier<void> {
  late final _$args = ref.$arg as String;
  String get accountId => _$args;

  void build(String accountId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
