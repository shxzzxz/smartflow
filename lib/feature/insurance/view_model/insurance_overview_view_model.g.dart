// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'insurance_overview_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(InsuranceOverviewViewModel)
final insuranceOverviewViewModelProvider =
    InsuranceOverviewViewModelProvider._();

final class InsuranceOverviewViewModelProvider
    extends
        $AsyncNotifierProvider<
          InsuranceOverviewViewModel,
          InsuranceOverviewViewState
        > {
  InsuranceOverviewViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'insuranceOverviewViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$insuranceOverviewViewModelHash();

  @$internal
  @override
  InsuranceOverviewViewModel create() => InsuranceOverviewViewModel();
}

String _$insuranceOverviewViewModelHash() =>
    r'cf0bafa8bb6461f1d3c206be19edcec15e05dc9d';

abstract class _$InsuranceOverviewViewModel
    extends $AsyncNotifier<InsuranceOverviewViewState> {
  FutureOr<InsuranceOverviewViewState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<InsuranceOverviewViewState>,
              InsuranceOverviewViewState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<InsuranceOverviewViewState>,
                InsuranceOverviewViewState
              >,
              AsyncValue<InsuranceOverviewViewState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
