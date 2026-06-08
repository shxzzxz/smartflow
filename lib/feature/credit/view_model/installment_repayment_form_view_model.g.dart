// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'installment_repayment_form_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(InstallmentRepaymentFormViewModel)
final installmentRepaymentFormViewModelProvider =
    InstallmentRepaymentFormViewModelFamily._();

final class InstallmentRepaymentFormViewModelProvider
    extends
        $AsyncNotifierProvider<
          InstallmentRepaymentFormViewModel,
          InstallmentRepaymentFormState
        > {
  InstallmentRepaymentFormViewModelProvider._({
    required InstallmentRepaymentFormViewModelFamily super.from,
    required InstallmentRepaymentFormArgs super.argument,
  }) : super(
         retry: null,
         name: r'installmentRepaymentFormViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() =>
      _$installmentRepaymentFormViewModelHash();

  @override
  String toString() {
    return r'installmentRepaymentFormViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  InstallmentRepaymentFormViewModel create() =>
      InstallmentRepaymentFormViewModel();

  @override
  bool operator ==(Object other) {
    return other is InstallmentRepaymentFormViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$installmentRepaymentFormViewModelHash() =>
    r'2ffd7489e1dbb64f7291ac7d36057d19405b482c';

final class InstallmentRepaymentFormViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          InstallmentRepaymentFormViewModel,
          AsyncValue<InstallmentRepaymentFormState>,
          InstallmentRepaymentFormState,
          FutureOr<InstallmentRepaymentFormState>,
          InstallmentRepaymentFormArgs
        > {
  InstallmentRepaymentFormViewModelFamily._()
    : super(
        retry: null,
        name: r'installmentRepaymentFormViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  InstallmentRepaymentFormViewModelProvider call(
    InstallmentRepaymentFormArgs args,
  ) => InstallmentRepaymentFormViewModelProvider._(argument: args, from: this);

  @override
  String toString() => r'installmentRepaymentFormViewModelProvider';
}

abstract class _$InstallmentRepaymentFormViewModel
    extends $AsyncNotifier<InstallmentRepaymentFormState> {
  late final _$args = ref.$arg as InstallmentRepaymentFormArgs;
  InstallmentRepaymentFormArgs get args => _$args;

  FutureOr<InstallmentRepaymentFormState> build(
    InstallmentRepaymentFormArgs args,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<InstallmentRepaymentFormState>,
              InstallmentRepaymentFormState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<InstallmentRepaymentFormState>,
                InstallmentRepaymentFormState
              >,
              AsyncValue<InstallmentRepaymentFormState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
