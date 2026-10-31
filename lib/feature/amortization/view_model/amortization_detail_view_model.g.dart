// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'amortization_detail_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AmortizationDetailViewModel)
final amortizationDetailViewModelProvider =
    AmortizationDetailViewModelFamily._();

final class AmortizationDetailViewModelProvider
    extends
        $AsyncNotifierProvider<
          AmortizationDetailViewModel,
          AmortizationDetailState?
        > {
  AmortizationDetailViewModelProvider._({
    required AmortizationDetailViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'amortizationDetailViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$amortizationDetailViewModelHash();

  @override
  String toString() {
    return r'amortizationDetailViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AmortizationDetailViewModel create() => AmortizationDetailViewModel();

  @override
  bool operator ==(Object other) {
    return other is AmortizationDetailViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$amortizationDetailViewModelHash() =>
    r'54e34ced4eaf7d43627c5f896ad9c4e29e10a0b2';

final class AmortizationDetailViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          AmortizationDetailViewModel,
          AsyncValue<AmortizationDetailState?>,
          AmortizationDetailState?,
          FutureOr<AmortizationDetailState?>,
          String
        > {
  AmortizationDetailViewModelFamily._()
    : super(
        retry: null,
        name: r'amortizationDetailViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AmortizationDetailViewModelProvider call(String planId) =>
      AmortizationDetailViewModelProvider._(argument: planId, from: this);

  @override
  String toString() => r'amortizationDetailViewModelProvider';
}

abstract class _$AmortizationDetailViewModel
    extends $AsyncNotifier<AmortizationDetailState?> {
  late final _$args = ref.$arg as String;
  String get planId => _$args;

  FutureOr<AmortizationDetailState?> build(String planId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<AmortizationDetailState?>,
              AmortizationDetailState?
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<AmortizationDetailState?>,
                AmortizationDetailState?
              >,
              AsyncValue<AmortizationDetailState?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
