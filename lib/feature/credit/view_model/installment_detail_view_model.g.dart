// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'installment_detail_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(InstallmentDetailViewModel)
final installmentDetailViewModelProvider = InstallmentDetailViewModelFamily._();

final class InstallmentDetailViewModelProvider
    extends
        $AsyncNotifierProvider<
          InstallmentDetailViewModel,
          InstallmentDetailState
        > {
  InstallmentDetailViewModelProvider._({
    required InstallmentDetailViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'installmentDetailViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$installmentDetailViewModelHash();

  @override
  String toString() {
    return r'installmentDetailViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  InstallmentDetailViewModel create() => InstallmentDetailViewModel();

  @override
  bool operator ==(Object other) {
    return other is InstallmentDetailViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$installmentDetailViewModelHash() =>
    r'18e71dc5ed32a66fb67665c8dac14570a34f916e';

final class InstallmentDetailViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          InstallmentDetailViewModel,
          AsyncValue<InstallmentDetailState>,
          InstallmentDetailState,
          FutureOr<InstallmentDetailState>,
          String
        > {
  InstallmentDetailViewModelFamily._()
    : super(
        retry: null,
        name: r'installmentDetailViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  InstallmentDetailViewModelProvider call(String contractId) =>
      InstallmentDetailViewModelProvider._(argument: contractId, from: this);

  @override
  String toString() => r'installmentDetailViewModelProvider';
}

abstract class _$InstallmentDetailViewModel
    extends $AsyncNotifier<InstallmentDetailState> {
  late final _$args = ref.$arg as String;
  String get contractId => _$args;

  FutureOr<InstallmentDetailState> build(String contractId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<InstallmentDetailState>, InstallmentDetailState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<InstallmentDetailState>,
                InstallmentDetailState
              >,
              AsyncValue<InstallmentDetailState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
