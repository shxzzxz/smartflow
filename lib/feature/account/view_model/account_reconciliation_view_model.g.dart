// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_reconciliation_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountReconciliationData)
final accountReconciliationDataProvider = AccountReconciliationDataFamily._();

final class AccountReconciliationDataProvider
    extends
        $FunctionalProvider<
          AsyncValue<AccountReconciliationState>,
          AccountReconciliationState,
          Stream<AccountReconciliationState>
        >
    with
        $FutureModifier<AccountReconciliationState>,
        $StreamProvider<AccountReconciliationState> {
  AccountReconciliationDataProvider._({
    required AccountReconciliationDataFamily super.from,
    required AccountReconciliationQuery super.argument,
  }) : super(
         retry: null,
         name: r'accountReconciliationDataProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountReconciliationDataHash();

  @override
  String toString() {
    return r'accountReconciliationDataProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<AccountReconciliationState> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<AccountReconciliationState> create(Ref ref) {
    final argument = this.argument as AccountReconciliationQuery;
    return accountReconciliationData(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AccountReconciliationDataProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountReconciliationDataHash() =>
    r'6af9acc39714fabc1018972d6a4dc1244a171fb8';

final class AccountReconciliationDataFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<AccountReconciliationState>,
          AccountReconciliationQuery
        > {
  AccountReconciliationDataFamily._()
    : super(
        retry: null,
        name: r'accountReconciliationDataProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountReconciliationDataProvider call(AccountReconciliationQuery query) =>
      AccountReconciliationDataProvider._(argument: query, from: this);

  @override
  String toString() => r'accountReconciliationDataProvider';
}

@ProviderFor(AccountReconciliationSelection)
final accountReconciliationSelectionProvider =
    AccountReconciliationSelectionFamily._();

final class AccountReconciliationSelectionProvider
    extends
        $NotifierProvider<
          AccountReconciliationSelection,
          AccountReconciliationSelectionState
        > {
  AccountReconciliationSelectionProvider._({
    required AccountReconciliationSelectionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountReconciliationSelectionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountReconciliationSelectionHash();

  @override
  String toString() {
    return r'accountReconciliationSelectionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AccountReconciliationSelection create() => AccountReconciliationSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountReconciliationSelectionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountReconciliationSelectionState>(
        value,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountReconciliationSelectionProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountReconciliationSelectionHash() =>
    r'5fe0622102427eb83c0272b35c34d19baa65236e';

final class AccountReconciliationSelectionFamily extends $Family
    with
        $ClassFamilyOverride<
          AccountReconciliationSelection,
          AccountReconciliationSelectionState,
          AccountReconciliationSelectionState,
          AccountReconciliationSelectionState,
          String
        > {
  AccountReconciliationSelectionFamily._()
    : super(
        retry: null,
        name: r'accountReconciliationSelectionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountReconciliationSelectionProvider call(String accountId) =>
      AccountReconciliationSelectionProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountReconciliationSelectionProvider';
}

abstract class _$AccountReconciliationSelection
    extends $Notifier<AccountReconciliationSelectionState> {
  late final _$args = ref.$arg as String;
  String get accountId => _$args;

  AccountReconciliationSelectionState build(String accountId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AccountReconciliationSelectionState,
              AccountReconciliationSelectionState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AccountReconciliationSelectionState,
                AccountReconciliationSelectionState
              >,
              AccountReconciliationSelectionState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(AccountReconciliationViewModel)
final accountReconciliationViewModelProvider =
    AccountReconciliationViewModelFamily._();

final class AccountReconciliationViewModelProvider
    extends
        $NotifierProvider<
          AccountReconciliationViewModel,
          AccountReconciliationPageState
        > {
  AccountReconciliationViewModelProvider._({
    required AccountReconciliationViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountReconciliationViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountReconciliationViewModelHash();

  @override
  String toString() {
    return r'accountReconciliationViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AccountReconciliationViewModel create() => AccountReconciliationViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountReconciliationPageState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountReconciliationPageState>(
        value,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountReconciliationViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountReconciliationViewModelHash() =>
    r'7554b20b7cc4880f83e86afe4ca1f622c6f2c297';

final class AccountReconciliationViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          AccountReconciliationViewModel,
          AccountReconciliationPageState,
          AccountReconciliationPageState,
          AccountReconciliationPageState,
          String
        > {
  AccountReconciliationViewModelFamily._()
    : super(
        retry: null,
        name: r'accountReconciliationViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountReconciliationViewModelProvider call(String accountId) =>
      AccountReconciliationViewModelProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountReconciliationViewModelProvider';
}

abstract class _$AccountReconciliationViewModel
    extends $Notifier<AccountReconciliationPageState> {
  late final _$args = ref.$arg as String;
  String get accountId => _$args;

  AccountReconciliationPageState build(String accountId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AccountReconciliationPageState,
              AccountReconciliationPageState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AccountReconciliationPageState,
                AccountReconciliationPageState
              >,
              AccountReconciliationPageState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
