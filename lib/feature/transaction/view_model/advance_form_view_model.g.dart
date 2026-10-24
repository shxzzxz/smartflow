// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'advance_form_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AdvanceCollectionFormViewModel)
final advanceCollectionFormViewModelProvider =
    AdvanceCollectionFormViewModelFamily._();

final class AdvanceCollectionFormViewModelProvider
    extends
        $AsyncNotifierProvider<
          AdvanceCollectionFormViewModel,
          AdvanceCollectionFormState
        > {
  AdvanceCollectionFormViewModelProvider._({
    required AdvanceCollectionFormViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'advanceCollectionFormViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$advanceCollectionFormViewModelHash();

  @override
  String toString() {
    return r'advanceCollectionFormViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AdvanceCollectionFormViewModel create() => AdvanceCollectionFormViewModel();

  @override
  bool operator ==(Object other) {
    return other is AdvanceCollectionFormViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$advanceCollectionFormViewModelHash() =>
    r'4a75d508f8bc1f910400913e101520e5a3494322';

final class AdvanceCollectionFormViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          AdvanceCollectionFormViewModel,
          AsyncValue<AdvanceCollectionFormState>,
          AdvanceCollectionFormState,
          FutureOr<AdvanceCollectionFormState>,
          String
        > {
  AdvanceCollectionFormViewModelFamily._()
    : super(
        retry: null,
        name: r'advanceCollectionFormViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AdvanceCollectionFormViewModelProvider call(String advanceTransactionId) =>
      AdvanceCollectionFormViewModelProvider._(
        argument: advanceTransactionId,
        from: this,
      );

  @override
  String toString() => r'advanceCollectionFormViewModelProvider';
}

abstract class _$AdvanceCollectionFormViewModel
    extends $AsyncNotifier<AdvanceCollectionFormState> {
  late final _$args = ref.$arg as String;
  String get advanceTransactionId => _$args;

  FutureOr<AdvanceCollectionFormState> build(String advanceTransactionId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<AdvanceCollectionFormState>,
              AdvanceCollectionFormState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<AdvanceCollectionFormState>,
                AdvanceCollectionFormState
              >,
              AsyncValue<AdvanceCollectionFormState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(AdvanceSettlementFormViewModel)
final advanceSettlementFormViewModelProvider =
    AdvanceSettlementFormViewModelFamily._();

final class AdvanceSettlementFormViewModelProvider
    extends
        $AsyncNotifierProvider<
          AdvanceSettlementFormViewModel,
          AdvanceSettlementFormState
        > {
  AdvanceSettlementFormViewModelProvider._({
    required AdvanceSettlementFormViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'advanceSettlementFormViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$advanceSettlementFormViewModelHash();

  @override
  String toString() {
    return r'advanceSettlementFormViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AdvanceSettlementFormViewModel create() => AdvanceSettlementFormViewModel();

  @override
  bool operator ==(Object other) {
    return other is AdvanceSettlementFormViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$advanceSettlementFormViewModelHash() =>
    r'8cac4ee4d8f80dd353f74e82842197562f04cde5';

final class AdvanceSettlementFormViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          AdvanceSettlementFormViewModel,
          AsyncValue<AdvanceSettlementFormState>,
          AdvanceSettlementFormState,
          FutureOr<AdvanceSettlementFormState>,
          String
        > {
  AdvanceSettlementFormViewModelFamily._()
    : super(
        retry: null,
        name: r'advanceSettlementFormViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AdvanceSettlementFormViewModelProvider call(String advanceTransactionId) =>
      AdvanceSettlementFormViewModelProvider._(
        argument: advanceTransactionId,
        from: this,
      );

  @override
  String toString() => r'advanceSettlementFormViewModelProvider';
}

abstract class _$AdvanceSettlementFormViewModel
    extends $AsyncNotifier<AdvanceSettlementFormState> {
  late final _$args = ref.$arg as String;
  String get advanceTransactionId => _$args;

  FutureOr<AdvanceSettlementFormState> build(String advanceTransactionId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<AdvanceSettlementFormState>,
              AdvanceSettlementFormState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<AdvanceSettlementFormState>,
                AdvanceSettlementFormState
              >,
              AsyncValue<AdvanceSettlementFormState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(AdvanceFormViewModel)
final advanceFormViewModelProvider = AdvanceFormViewModelFamily._();

final class AdvanceFormViewModelProvider
    extends $AsyncNotifierProvider<AdvanceFormViewModel, AdvanceFormState> {
  AdvanceFormViewModelProvider._({
    required AdvanceFormViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'advanceFormViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$advanceFormViewModelHash();

  @override
  String toString() {
    return r'advanceFormViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AdvanceFormViewModel create() => AdvanceFormViewModel();

  @override
  bool operator ==(Object other) {
    return other is AdvanceFormViewModelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$advanceFormViewModelHash() =>
    r'4e16e86ed2d11cc4847a7ac8657fd3287ef915df';

final class AdvanceFormViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          AdvanceFormViewModel,
          AsyncValue<AdvanceFormState>,
          AdvanceFormState,
          FutureOr<AdvanceFormState>,
          String
        > {
  AdvanceFormViewModelFamily._()
    : super(
        retry: null,
        name: r'advanceFormViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AdvanceFormViewModelProvider call(String advanceTransactionId) =>
      AdvanceFormViewModelProvider._(
        argument: advanceTransactionId,
        from: this,
      );

  @override
  String toString() => r'advanceFormViewModelProvider';
}

abstract class _$AdvanceFormViewModel extends $AsyncNotifier<AdvanceFormState> {
  late final _$args = ref.$arg as String;
  String get advanceTransactionId => _$args;

  FutureOr<AdvanceFormState> build(String advanceTransactionId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<AdvanceFormState>, AdvanceFormState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AdvanceFormState>, AdvanceFormState>,
              AsyncValue<AdvanceFormState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(AccountAdvanceFormViewModel)
final accountAdvanceFormViewModelProvider =
    AccountAdvanceFormViewModelFamily._();

final class AccountAdvanceFormViewModelProvider
    extends
        $AsyncNotifierProvider<
          AccountAdvanceFormViewModel,
          AccountAdvanceFormState
        > {
  AccountAdvanceFormViewModelProvider._({
    required AccountAdvanceFormViewModelFamily super.from,
    required AccountAdvanceFormTarget super.argument,
  }) : super(
         retry: null,
         name: r'accountAdvanceFormViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountAdvanceFormViewModelHash();

  @override
  String toString() {
    return r'accountAdvanceFormViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AccountAdvanceFormViewModel create() => AccountAdvanceFormViewModel();

  @override
  bool operator ==(Object other) {
    return other is AccountAdvanceFormViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountAdvanceFormViewModelHash() =>
    r'fd69d33e35338fdbbde2b3c2df0e046223aedf94';

final class AccountAdvanceFormViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          AccountAdvanceFormViewModel,
          AsyncValue<AccountAdvanceFormState>,
          AccountAdvanceFormState,
          FutureOr<AccountAdvanceFormState>,
          AccountAdvanceFormTarget
        > {
  AccountAdvanceFormViewModelFamily._()
    : super(
        retry: null,
        name: r'accountAdvanceFormViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountAdvanceFormViewModelProvider call(AccountAdvanceFormTarget target) =>
      AccountAdvanceFormViewModelProvider._(argument: target, from: this);

  @override
  String toString() => r'accountAdvanceFormViewModelProvider';
}

abstract class _$AccountAdvanceFormViewModel
    extends $AsyncNotifier<AccountAdvanceFormState> {
  late final _$args = ref.$arg as AccountAdvanceFormTarget;
  AccountAdvanceFormTarget get target => _$args;

  FutureOr<AccountAdvanceFormState> build(AccountAdvanceFormTarget target);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<AccountAdvanceFormState>,
              AccountAdvanceFormState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<AccountAdvanceFormState>,
                AccountAdvanceFormState
              >,
              AsyncValue<AccountAdvanceFormState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
