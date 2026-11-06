import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/insurance/insurance_query_api.dart';

part 'member_coverage_view_model.g.dart';

@riverpod
class MemberCoverageViewModel extends _$MemberCoverageViewModel {
  @override
  Future<MemberCoverageOverview?> build(String insuredPersonId) {
    return ref
        .watch(insuranceCoverageQueryServiceProvider)
        .memberCoverage(insuredPersonId);
  }
}
