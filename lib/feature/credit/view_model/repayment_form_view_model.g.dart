// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'repayment_form_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RepaymentFormViewModel)
final repaymentFormViewModelProvider = RepaymentFormViewModelFamily._();

final class RepaymentFormViewModelProvider
    extends $AsyncNotifierProvider<RepaymentFormViewModel, RepaymentFormState> {
  RepaymentFormViewModelProvider._({
    required RepaymentFormViewModelFamily super.from,
    required RepaymentFormArgs super.argument,
  }) : super(
         retry: null,
         name: r'repaymentFormViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$repaymentFormViewModelHash();

  @override
  String toString() {
    return r'repaymentFormViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  RepaymentFormViewModel create() => RepaymentFormViewModel();

  @override
  bool operator ==(Object other) {
    return other is RepaymentFormViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$repaymentFormViewModelHash() =>
    r'bc1ab1dc9a5b8249f4b79615b1a567f0a64ca1dd';

final class RepaymentFormViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          RepaymentFormViewModel,
          AsyncValue<RepaymentFormState>,
          RepaymentFormState,
          FutureOr<RepaymentFormState>,
          RepaymentFormArgs
        > {
  RepaymentFormViewModelFamily._()
    : super(
        retry: null,
        name: r'repaymentFormViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  RepaymentFormViewModelProvider call(RepaymentFormArgs args) =>
      RepaymentFormViewModelProvider._(argument: args, from: this);

  @override
  String toString() => r'repaymentFormViewModelProvider';
}

abstract class _$RepaymentFormViewModel
    extends $AsyncNotifier<RepaymentFormState> {
  late final _$args = ref.$arg as RepaymentFormArgs;
  RepaymentFormArgs get args => _$args;

  FutureOr<RepaymentFormState> build(RepaymentFormArgs args);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<RepaymentFormState>, RepaymentFormState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<RepaymentFormState>, RepaymentFormState>,
              AsyncValue<RepaymentFormState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
