// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'social_insurance_detail_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SocialInsuranceDetailViewModel)
final socialInsuranceDetailViewModelProvider =
    SocialInsuranceDetailViewModelFamily._();

final class SocialInsuranceDetailViewModelProvider
    extends
        $AsyncNotifierProvider<
          SocialInsuranceDetailViewModel,
          SocialInsuranceDetailState?
        > {
  SocialInsuranceDetailViewModelProvider._({
    required SocialInsuranceDetailViewModelFamily super.from,
    required (String, InsuranceSourceType) super.argument,
  }) : super(
         retry: null,
         name: r'socialInsuranceDetailViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$socialInsuranceDetailViewModelHash();

  @override
  String toString() {
    return r'socialInsuranceDetailViewModelProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  SocialInsuranceDetailViewModel create() => SocialInsuranceDetailViewModel();

  @override
  bool operator ==(Object other) {
    return other is SocialInsuranceDetailViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$socialInsuranceDetailViewModelHash() =>
    r'790700f67d1c331e58af2d27916a246406d0f81e';

final class SocialInsuranceDetailViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          SocialInsuranceDetailViewModel,
          AsyncValue<SocialInsuranceDetailState?>,
          SocialInsuranceDetailState?,
          FutureOr<SocialInsuranceDetailState?>,
          (String, InsuranceSourceType)
        > {
  SocialInsuranceDetailViewModelFamily._()
    : super(
        retry: null,
        name: r'socialInsuranceDetailViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SocialInsuranceDetailViewModelProvider call(
    String insuranceId,
    InsuranceSourceType sourceType,
  ) => SocialInsuranceDetailViewModelProvider._(
    argument: (insuranceId, sourceType),
    from: this,
  );

  @override
  String toString() => r'socialInsuranceDetailViewModelProvider';
}

abstract class _$SocialInsuranceDetailViewModel
    extends $AsyncNotifier<SocialInsuranceDetailState?> {
  late final _$args = ref.$arg as (String, InsuranceSourceType);
  String get insuranceId => _$args.$1;
  InsuranceSourceType get sourceType => _$args.$2;

  FutureOr<SocialInsuranceDetailState?> build(
    String insuranceId,
    InsuranceSourceType sourceType,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<SocialInsuranceDetailState?>,
              SocialInsuranceDetailState?
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<SocialInsuranceDetailState?>,
                SocialInsuranceDetailState?
              >,
              AsyncValue<SocialInsuranceDetailState?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
