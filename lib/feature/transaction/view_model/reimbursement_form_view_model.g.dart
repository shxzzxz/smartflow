// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reimbursement_form_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ReimbursementReceiptFormViewModel)
final reimbursementReceiptFormViewModelProvider =
    ReimbursementReceiptFormViewModelFamily._();

final class ReimbursementReceiptFormViewModelProvider
    extends
        $AsyncNotifierProvider<
          ReimbursementReceiptFormViewModel,
          ReimbursementReceiptFormState
        > {
  ReimbursementReceiptFormViewModelProvider._({
    required ReimbursementReceiptFormViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'reimbursementReceiptFormViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() =>
      _$reimbursementReceiptFormViewModelHash();

  @override
  String toString() {
    return r'reimbursementReceiptFormViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ReimbursementReceiptFormViewModel create() =>
      ReimbursementReceiptFormViewModel();

  @override
  bool operator ==(Object other) {
    return other is ReimbursementReceiptFormViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reimbursementReceiptFormViewModelHash() =>
    r'1022780ac2375bf850ad4247d3cbd5eb76d613fb';

final class ReimbursementReceiptFormViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          ReimbursementReceiptFormViewModel,
          AsyncValue<ReimbursementReceiptFormState>,
          ReimbursementReceiptFormState,
          FutureOr<ReimbursementReceiptFormState>,
          String
        > {
  ReimbursementReceiptFormViewModelFamily._()
    : super(
        retry: null,
        name: r'reimbursementReceiptFormViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ReimbursementReceiptFormViewModelProvider call(String advanceTransactionId) =>
      ReimbursementReceiptFormViewModelProvider._(
        argument: advanceTransactionId,
        from: this,
      );

  @override
  String toString() => r'reimbursementReceiptFormViewModelProvider';
}

abstract class _$ReimbursementReceiptFormViewModel
    extends $AsyncNotifier<ReimbursementReceiptFormState> {
  late final _$args = ref.$arg as String;
  String get advanceTransactionId => _$args;

  FutureOr<ReimbursementReceiptFormState> build(String advanceTransactionId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<ReimbursementReceiptFormState>,
              ReimbursementReceiptFormState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<ReimbursementReceiptFormState>,
                ReimbursementReceiptFormState
              >,
              AsyncValue<ReimbursementReceiptFormState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(ReimbursementCloseFormViewModel)
final reimbursementCloseFormViewModelProvider =
    ReimbursementCloseFormViewModelFamily._();

final class ReimbursementCloseFormViewModelProvider
    extends
        $AsyncNotifierProvider<
          ReimbursementCloseFormViewModel,
          ReimbursementCloseFormState
        > {
  ReimbursementCloseFormViewModelProvider._({
    required ReimbursementCloseFormViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'reimbursementCloseFormViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reimbursementCloseFormViewModelHash();

  @override
  String toString() {
    return r'reimbursementCloseFormViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ReimbursementCloseFormViewModel create() => ReimbursementCloseFormViewModel();

  @override
  bool operator ==(Object other) {
    return other is ReimbursementCloseFormViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reimbursementCloseFormViewModelHash() =>
    r'f6ebbe1452e3e9fc66bdeb914a19682d23a98ad0';

final class ReimbursementCloseFormViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          ReimbursementCloseFormViewModel,
          AsyncValue<ReimbursementCloseFormState>,
          ReimbursementCloseFormState,
          FutureOr<ReimbursementCloseFormState>,
          String
        > {
  ReimbursementCloseFormViewModelFamily._()
    : super(
        retry: null,
        name: r'reimbursementCloseFormViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ReimbursementCloseFormViewModelProvider call(String advanceTransactionId) =>
      ReimbursementCloseFormViewModelProvider._(
        argument: advanceTransactionId,
        from: this,
      );

  @override
  String toString() => r'reimbursementCloseFormViewModelProvider';
}

abstract class _$ReimbursementCloseFormViewModel
    extends $AsyncNotifier<ReimbursementCloseFormState> {
  late final _$args = ref.$arg as String;
  String get advanceTransactionId => _$args;

  FutureOr<ReimbursementCloseFormState> build(String advanceTransactionId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<ReimbursementCloseFormState>,
              ReimbursementCloseFormState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<ReimbursementCloseFormState>,
                ReimbursementCloseFormState
              >,
              AsyncValue<ReimbursementCloseFormState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
