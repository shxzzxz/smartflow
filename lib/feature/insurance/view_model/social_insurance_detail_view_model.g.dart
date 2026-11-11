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
    required String super.argument,
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
        '($argument)';
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
    r'1af3a8c46cd7ecd503a993ae99aaa82e2cf337ac';

final class SocialInsuranceDetailViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          SocialInsuranceDetailViewModel,
          AsyncValue<SocialInsuranceDetailState?>,
          SocialInsuranceDetailState?,
          FutureOr<SocialInsuranceDetailState?>,
          String
        > {
  SocialInsuranceDetailViewModelFamily._()
    : super(
        retry: null,
        name: r'socialInsuranceDetailViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SocialInsuranceDetailViewModelProvider call(String insuranceId) =>
      SocialInsuranceDetailViewModelProvider._(
        argument: insuranceId,
        from: this,
      );

  @override
  String toString() => r'socialInsuranceDetailViewModelProvider';
}

abstract class _$SocialInsuranceDetailViewModel
    extends $AsyncNotifier<SocialInsuranceDetailState?> {
  late final _$args = ref.$arg as String;
  String get insuranceId => _$args;

  FutureOr<SocialInsuranceDetailState?> build(String insuranceId);
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
    return element.handleCreate(ref, () => build(_$args));
  }
}
