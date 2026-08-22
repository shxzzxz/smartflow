// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receivable_payable_form_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ReceivablePayableFormViewModel)
final receivablePayableFormViewModelProvider =
    ReceivablePayableFormViewModelFamily._();

final class ReceivablePayableFormViewModelProvider
    extends
        $AsyncNotifierProvider<
          ReceivablePayableFormViewModel,
          ReceivablePayableFormState
        > {
  ReceivablePayableFormViewModelProvider._({
    required ReceivablePayableFormViewModelFamily super.from,
    required ReceivablePayableFormArgs super.argument,
  }) : super(
         retry: null,
         name: r'receivablePayableFormViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$receivablePayableFormViewModelHash();

  @override
  String toString() {
    return r'receivablePayableFormViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ReceivablePayableFormViewModel create() => ReceivablePayableFormViewModel();

  @override
  bool operator ==(Object other) {
    return other is ReceivablePayableFormViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$receivablePayableFormViewModelHash() =>
    r'4c4e3ff09308f5099a8d59c5893fcd6f5fb3aa2b';

final class ReceivablePayableFormViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          ReceivablePayableFormViewModel,
          AsyncValue<ReceivablePayableFormState>,
          ReceivablePayableFormState,
          FutureOr<ReceivablePayableFormState>,
          ReceivablePayableFormArgs
        > {
  ReceivablePayableFormViewModelFamily._()
    : super(
        retry: null,
        name: r'receivablePayableFormViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ReceivablePayableFormViewModelProvider call(ReceivablePayableFormArgs args) =>
      ReceivablePayableFormViewModelProvider._(argument: args, from: this);

  @override
  String toString() => r'receivablePayableFormViewModelProvider';
}

abstract class _$ReceivablePayableFormViewModel
    extends $AsyncNotifier<ReceivablePayableFormState> {
  late final _$args = ref.$arg as ReceivablePayableFormArgs;
  ReceivablePayableFormArgs get args => _$args;

  FutureOr<ReceivablePayableFormState> build(ReceivablePayableFormArgs args);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<ReceivablePayableFormState>,
              ReceivablePayableFormState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<ReceivablePayableFormState>,
                ReceivablePayableFormState
              >,
              AsyncValue<ReceivablePayableFormState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
