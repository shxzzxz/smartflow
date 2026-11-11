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
    required (String?, String?) super.argument,
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
    r'e44e9387addd04813b730a03ea8edc7a76d1f7ae';

final class SocialInsuranceFormViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          SocialInsuranceFormViewModel,
          AsyncValue<SocialInsuranceFormState?>,
          SocialInsuranceFormState?,
          FutureOr<SocialInsuranceFormState?>,
          (String?, String?)
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
    String? initialInsuredPersonId,
  ) => SocialInsuranceFormViewModelProvider._(
    argument: (insuranceId, initialInsuredPersonId),
    from: this,
  );

  @override
  String toString() => r'socialInsuranceFormViewModelProvider';
}

abstract class _$SocialInsuranceFormViewModel
    extends $AsyncNotifier<SocialInsuranceFormState?> {
  late final _$args = ref.$arg as (String?, String?);
  String? get insuranceId => _$args.$1;
  String? get initialInsuredPersonId => _$args.$2;

  FutureOr<SocialInsuranceFormState?> build(
    String? insuranceId,
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
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
