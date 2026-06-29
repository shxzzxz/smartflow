// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'installment_contract_edit_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(InstallmentContractEditViewModel)
final installmentContractEditViewModelProvider =
    InstallmentContractEditViewModelFamily._();

final class InstallmentContractEditViewModelProvider
    extends
        $AsyncNotifierProvider<
          InstallmentContractEditViewModel,
          InstallmentContractEditState
        > {
  InstallmentContractEditViewModelProvider._({
    required InstallmentContractEditViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'installmentContractEditViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$installmentContractEditViewModelHash();

  @override
  String toString() {
    return r'installmentContractEditViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  InstallmentContractEditViewModel create() =>
      InstallmentContractEditViewModel();

  @override
  bool operator ==(Object other) {
    return other is InstallmentContractEditViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$installmentContractEditViewModelHash() =>
    r'4e251c5f06a5bec981aec0259d257bcf7653de09';

final class InstallmentContractEditViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          InstallmentContractEditViewModel,
          AsyncValue<InstallmentContractEditState>,
          InstallmentContractEditState,
          FutureOr<InstallmentContractEditState>,
          String
        > {
  InstallmentContractEditViewModelFamily._()
    : super(
        retry: null,
        name: r'installmentContractEditViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  InstallmentContractEditViewModelProvider call(String contractId) =>
      InstallmentContractEditViewModelProvider._(
        argument: contractId,
        from: this,
      );

  @override
  String toString() => r'installmentContractEditViewModelProvider';
}

abstract class _$InstallmentContractEditViewModel
    extends $AsyncNotifier<InstallmentContractEditState> {
  late final _$args = ref.$arg as String;
  String get contractId => _$args;

  FutureOr<InstallmentContractEditState> build(String contractId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<InstallmentContractEditState>,
              InstallmentContractEditState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<InstallmentContractEditState>,
                InstallmentContractEditState
              >,
              AsyncValue<InstallmentContractEditState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
