// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'commercial_insurance_responsibilities_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CommercialInsuranceResponsibilitiesViewModel)
final commercialInsuranceResponsibilitiesViewModelProvider =
    CommercialInsuranceResponsibilitiesViewModelFamily._();

final class CommercialInsuranceResponsibilitiesViewModelProvider
    extends
        $AsyncNotifierProvider<
          CommercialInsuranceResponsibilitiesViewModel,
          CommercialInsuranceResponsibilitiesState?
        > {
  CommercialInsuranceResponsibilitiesViewModelProvider._({
    required CommercialInsuranceResponsibilitiesViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'commercialInsuranceResponsibilitiesViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() =>
      _$commercialInsuranceResponsibilitiesViewModelHash();

  @override
  String toString() {
    return r'commercialInsuranceResponsibilitiesViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CommercialInsuranceResponsibilitiesViewModel create() =>
      CommercialInsuranceResponsibilitiesViewModel();

  @override
  bool operator ==(Object other) {
    return other is CommercialInsuranceResponsibilitiesViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$commercialInsuranceResponsibilitiesViewModelHash() =>
    r'26a5035cc3ab2cdfae579dc96aa94d72bc58c8be';

final class CommercialInsuranceResponsibilitiesViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          CommercialInsuranceResponsibilitiesViewModel,
          AsyncValue<CommercialInsuranceResponsibilitiesState?>,
          CommercialInsuranceResponsibilitiesState?,
          FutureOr<CommercialInsuranceResponsibilitiesState?>,
          String
        > {
  CommercialInsuranceResponsibilitiesViewModelFamily._()
    : super(
        retry: null,
        name: r'commercialInsuranceResponsibilitiesViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CommercialInsuranceResponsibilitiesViewModelProvider call(
    String insuranceId,
  ) => CommercialInsuranceResponsibilitiesViewModelProvider._(
    argument: insuranceId,
    from: this,
  );

  @override
  String toString() => r'commercialInsuranceResponsibilitiesViewModelProvider';
}

abstract class _$CommercialInsuranceResponsibilitiesViewModel
    extends $AsyncNotifier<CommercialInsuranceResponsibilitiesState?> {
  late final _$args = ref.$arg as String;
  String get insuranceId => _$args;

  FutureOr<CommercialInsuranceResponsibilitiesState?> build(String insuranceId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<CommercialInsuranceResponsibilitiesState?>,
              CommercialInsuranceResponsibilitiesState?
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<CommercialInsuranceResponsibilitiesState?>,
                CommercialInsuranceResponsibilitiesState?
              >,
              AsyncValue<CommercialInsuranceResponsibilitiesState?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
