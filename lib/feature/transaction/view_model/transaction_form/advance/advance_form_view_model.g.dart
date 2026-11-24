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
    r'14ccb7c07c9c81359171475c8efd8a820a836fef';

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
    r'7501a52c47ca6280c086471bbfcc3de607f61f23';

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
    r'15c0918e0dddaa12dc145b4837d7cec0734b65ff';

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
