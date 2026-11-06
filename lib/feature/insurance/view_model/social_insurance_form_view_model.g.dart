// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'social_insurance_form_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SocialInsuranceFormViewModel)
final socialInsuranceFormViewModelProvider =
    SocialInsuranceFormViewModelFamily._();

final class SocialInsuranceFormViewModelProvider
    extends
        $AsyncNotifierProvider<
          SocialInsuranceFormViewModel,
          SocialInsuranceFormState?
        > {
  SocialInsuranceFormViewModelProvider._({
    required SocialInsuranceFormViewModelFamily super.from,
    required (String?, InsuranceSourceType, String?) super.argument,
  }) : super(
         retry: null,
         name: r'socialInsuranceFormViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$socialInsuranceFormViewModelHash();

  @override
  String toString() {
    return r'socialInsuranceFormViewModelProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  SocialInsuranceFormViewModel create() => SocialInsuranceFormViewModel();

  @override
  bool operator ==(Object other) {
    return other is SocialInsuranceFormViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$socialInsuranceFormViewModelHash() =>
    r'72172292a144e106e63c19fa974fe7e2b9b9acbc';

final class SocialInsuranceFormViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          SocialInsuranceFormViewModel,
          AsyncValue<SocialInsuranceFormState?>,
          SocialInsuranceFormState?,
          FutureOr<SocialInsuranceFormState?>,
          (String?, InsuranceSourceType, String?)
        > {
  SocialInsuranceFormViewModelFamily._()
    : super(
        retry: null,
        name: r'socialInsuranceFormViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SocialInsuranceFormViewModelProvider call(
    String? insuranceId,
    InsuranceSourceType sourceType,
    String? initialInsuredPersonId,
  ) => SocialInsuranceFormViewModelProvider._(
    argument: (insuranceId, sourceType, initialInsuredPersonId),
    from: this,
  );

  @override
  String toString() => r'socialInsuranceFormViewModelProvider';
}

abstract class _$SocialInsuranceFormViewModel
    extends $AsyncNotifier<SocialInsuranceFormState?> {
  late final _$args = ref.$arg as (String?, InsuranceSourceType, String?);
  String? get insuranceId => _$args.$1;
  InsuranceSourceType get sourceType => _$args.$2;
  String? get initialInsuredPersonId => _$args.$3;

  FutureOr<SocialInsuranceFormState?> build(
    String? insuranceId,
    InsuranceSourceType sourceType,
    String? initialInsuredPersonId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<SocialInsuranceFormState?>,
              SocialInsuranceFormState?
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<SocialInsuranceFormState?>,
                SocialInsuranceFormState?
              >,
              AsyncValue<SocialInsuranceFormState?>,
              Object?,
              Object?
            >;
    return element.handleCreate(
      ref,
      () => build(_$args.$1, _$args.$2, _$args.$3),
    );
  }
}
