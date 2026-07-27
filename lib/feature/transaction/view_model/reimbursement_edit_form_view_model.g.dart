// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reimbursement_edit_form_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ReimbursementEditFormViewModel)
final reimbursementEditFormViewModelProvider =
    ReimbursementEditFormViewModelFamily._();

final class ReimbursementEditFormViewModelProvider
    extends
        $AsyncNotifierProvider<
          ReimbursementEditFormViewModel,
          ReimbursementEditFormState
        > {
  ReimbursementEditFormViewModelProvider._({
    required ReimbursementEditFormViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'reimbursementEditFormViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reimbursementEditFormViewModelHash();

  @override
  String toString() {
    return r'reimbursementEditFormViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ReimbursementEditFormViewModel create() => ReimbursementEditFormViewModel();

  @override
  bool operator ==(Object other) {
    return other is ReimbursementEditFormViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reimbursementEditFormViewModelHash() =>
    r'6bb19429d829843096f9d2a27db8e81753c183f4';

final class ReimbursementEditFormViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          ReimbursementEditFormViewModel,
          AsyncValue<ReimbursementEditFormState>,
          ReimbursementEditFormState,
          FutureOr<ReimbursementEditFormState>,
          String
        > {
  ReimbursementEditFormViewModelFamily._()
    : super(
        retry: null,
        name: r'reimbursementEditFormViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ReimbursementEditFormViewModelProvider call(String transactionId) =>
      ReimbursementEditFormViewModelProvider._(
        argument: transactionId,
        from: this,
      );

  @override
  String toString() => r'reimbursementEditFormViewModelProvider';
}

abstract class _$ReimbursementEditFormViewModel
    extends $AsyncNotifier<ReimbursementEditFormState> {
  late final _$args = ref.$arg as String;
  String get transactionId => _$args;

  FutureOr<ReimbursementEditFormState> build(String transactionId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<ReimbursementEditFormState>,
              ReimbursementEditFormState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<ReimbursementEditFormState>,
                ReimbursementEditFormState
              >,
              AsyncValue<ReimbursementEditFormState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
