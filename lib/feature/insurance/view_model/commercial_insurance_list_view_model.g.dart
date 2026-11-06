// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'commercial_insurance_list_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CommercialInsuranceListViewModel)
final commercialInsuranceListViewModelProvider =
    CommercialInsuranceListViewModelProvider._();

final class CommercialInsuranceListViewModelProvider
    extends
        $AsyncNotifierProvider<
          CommercialInsuranceListViewModel,
          List<CommercialInsuranceListItem>
        > {
  CommercialInsuranceListViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'commercialInsuranceListViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$commercialInsuranceListViewModelHash();

  @$internal
  @override
  CommercialInsuranceListViewModel create() =>
      CommercialInsuranceListViewModel();
}

String _$commercialInsuranceListViewModelHash() =>
    r'9496d9ba3a05c4f6590ce62dd82eb0839dc8cf66';

abstract class _$CommercialInsuranceListViewModel
    extends $AsyncNotifier<List<CommercialInsuranceListItem>> {
  FutureOr<List<CommercialInsuranceListItem>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<CommercialInsuranceListItem>>,
              List<CommercialInsuranceListItem>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<CommercialInsuranceListItem>>,
                List<CommercialInsuranceListItem>
              >,
              AsyncValue<List<CommercialInsuranceListItem>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
