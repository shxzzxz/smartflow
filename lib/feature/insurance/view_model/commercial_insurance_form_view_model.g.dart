// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'commercial_insurance_form_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CommercialInsuranceFormViewModel)
final commercialInsuranceFormViewModelProvider =
    CommercialInsuranceFormViewModelFamily._();

final class CommercialInsuranceFormViewModelProvider
    extends
        $AsyncNotifierProvider<
          CommercialInsuranceFormViewModel,
          CommercialInsuranceFormState?
        > {
  CommercialInsuranceFormViewModelProvider._({
    required CommercialInsuranceFormViewModelFamily super.from,
    required (String?, String?) super.argument,
  }) : super(
         retry: null,
         name: r'commercialInsuranceFormViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$commercialInsuranceFormViewModelHash();

  @override
  String toString() {
    return r'commercialInsuranceFormViewModelProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  CommercialInsuranceFormViewModel create() =>
      CommercialInsuranceFormViewModel();

  @override
  bool operator ==(Object other) {
    return other is CommercialInsuranceFormViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$commercialInsuranceFormViewModelHash() =>
    r'09dc8db0ff2ea5f99cad5ca14a81c4e20051329c';

final class CommercialInsuranceFormViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          CommercialInsuranceFormViewModel,
          AsyncValue<CommercialInsuranceFormState?>,
          CommercialInsuranceFormState?,
          FutureOr<CommercialInsuranceFormState?>,
          (String?, String?)
        > {
  CommercialInsuranceFormViewModelFamily._()
    : super(
        retry: null,
        name: r'commercialInsuranceFormViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CommercialInsuranceFormViewModelProvider call(
    String? insuranceId,
    String? initialInsuredPersonId,
  ) => CommercialInsuranceFormViewModelProvider._(
    argument: (insuranceId, initialInsuredPersonId),
    from: this,
  );

  @override
  String toString() => r'commercialInsuranceFormViewModelProvider';
}

abstract class _$CommercialInsuranceFormViewModel
    extends $AsyncNotifier<CommercialInsuranceFormState?> {
  late final _$args = ref.$arg as (String?, String?);
  String? get insuranceId => _$args.$1;
  String? get initialInsuredPersonId => _$args.$2;

  FutureOr<CommercialInsuranceFormState?> build(
    String? insuranceId,
    String? initialInsuredPersonId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<CommercialInsuranceFormState?>,
              CommercialInsuranceFormState?
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<CommercialInsuranceFormState?>,
                CommercialInsuranceFormState?
              >,
              AsyncValue<CommercialInsuranceFormState?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
