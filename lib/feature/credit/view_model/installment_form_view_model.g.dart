// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'installment_form_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(InstallmentFormViewModel)
final installmentFormViewModelProvider = InstallmentFormViewModelFamily._();

final class InstallmentFormViewModelProvider
    extends
        $AsyncNotifierProvider<InstallmentFormViewModel, InstallmentFormState> {
  InstallmentFormViewModelProvider._({
    required InstallmentFormViewModelFamily super.from,
    required InstallmentFormArgs super.argument,
  }) : super(
         retry: null,
         name: r'installmentFormViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$installmentFormViewModelHash();

  @override
  String toString() {
    return r'installmentFormViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  InstallmentFormViewModel create() => InstallmentFormViewModel();

  @override
  bool operator ==(Object other) {
    return other is InstallmentFormViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$installmentFormViewModelHash() =>
    r'46aa51912c4f8ab96a4a48b1d97341c44a675884';

final class InstallmentFormViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          InstallmentFormViewModel,
          AsyncValue<InstallmentFormState>,
          InstallmentFormState,
          FutureOr<InstallmentFormState>,
          InstallmentFormArgs
        > {
  InstallmentFormViewModelFamily._()
    : super(
        retry: null,
        name: r'installmentFormViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  InstallmentFormViewModelProvider call(InstallmentFormArgs args) =>
      InstallmentFormViewModelProvider._(argument: args, from: this);

  @override
  String toString() => r'installmentFormViewModelProvider';
}

abstract class _$InstallmentFormViewModel
    extends $AsyncNotifier<InstallmentFormState> {
  late final _$args = ref.$arg as InstallmentFormArgs;
  InstallmentFormArgs get args => _$args;

  FutureOr<InstallmentFormState> build(InstallmentFormArgs args);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<InstallmentFormState>, InstallmentFormState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<InstallmentFormState>,
                InstallmentFormState
              >,
              AsyncValue<InstallmentFormState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
