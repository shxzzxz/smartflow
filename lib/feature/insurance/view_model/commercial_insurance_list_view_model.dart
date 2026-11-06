import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/insurance/insurance_query_api.dart';

part 'commercial_insurance_list_view_model.g.dart';

@riverpod
class CommercialInsuranceListViewModel
    extends _$CommercialInsuranceListViewModel {
  @override
  Future<List<CommercialInsuranceListItem>> build() {
    return ref
        .watch(insuranceCoverageQueryServiceProvider)
        .listCommercialInsurances();
  }
}
