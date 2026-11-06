// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'commercial_insurance_detail_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CommercialInsuranceDetailViewModel)
final commercialInsuranceDetailViewModelProvider =
    CommercialInsuranceDetailViewModelFamily._();

final class CommercialInsuranceDetailViewModelProvider
    extends
        $AsyncNotifierProvider<
          CommercialInsuranceDetailViewModel,
          CommercialInsuranceDetail?
        > {
  CommercialInsuranceDetailViewModelProvider._({
    required CommercialInsuranceDetailViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'commercialInsuranceDetailViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() =>
      _$commercialInsuranceDetailViewModelHash();

  @override
  String toString() {
    return r'commercialInsuranceDetailViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CommercialInsuranceDetailViewModel create() =>
      CommercialInsuranceDetailViewModel();

  @override
  bool operator ==(Object other) {
    return other is CommercialInsuranceDetailViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$commercialInsuranceDetailViewModelHash() =>
    r'ebbd7e8c368af7e31f6d1f54ffa94f1e16397a7b';

final class CommercialInsuranceDetailViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          CommercialInsuranceDetailViewModel,
          AsyncValue<CommercialInsuranceDetail?>,
          CommercialInsuranceDetail?,
          FutureOr<CommercialInsuranceDetail?>,
          String
        > {
  CommercialInsuranceDetailViewModelFamily._()
    : super(
        retry: null,
        name: r'commercialInsuranceDetailViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CommercialInsuranceDetailViewModelProvider call(String insuranceId) =>
      CommercialInsuranceDetailViewModelProvider._(
        argument: insuranceId,
        from: this,
      );

  @override
  String toString() => r'commercialInsuranceDetailViewModelProvider';
}

abstract class _$CommercialInsuranceDetailViewModel
    extends $AsyncNotifier<CommercialInsuranceDetail?> {
  late final _$args = ref.$arg as String;
  String get insuranceId => _$args;

  FutureOr<CommercialInsuranceDetail?> build(String insuranceId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<CommercialInsuranceDetail?>,
              CommercialInsuranceDetail?
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<CommercialInsuranceDetail?>,
                CommercialInsuranceDetail?
              >,
              AsyncValue<CommercialInsuranceDetail?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
