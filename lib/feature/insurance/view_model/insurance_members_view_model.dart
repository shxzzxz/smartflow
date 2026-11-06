import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/insurance/insurance_query_api.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import 'insurance_overview_view_model.dart';
import 'member_coverage_view_model.dart';

part 'insurance_members_view_model.g.dart';

final _logger = Logger('feature.insurance.members');

@riverpod
class InsuranceMembersViewModel extends _$InsuranceMembersViewModel {
  @override
  Future<List<InsuranceMemberListItem>> build() {
    return ref.watch(insuranceCoverageQueryServiceProvider).listMembers();
  }

  Future<UiActionOutcome<void>> delete(String insuredPersonId) {
    return guardUiAction(_logger, 'Delete insured person', () async {
      await ref.read(insuredPersonAppServiceProvider).delete(insuredPersonId);
      ref.invalidateSelf();
      ref.invalidate(insuranceOverviewViewModelProvider);
      ref.invalidate(memberCoverageViewModelProvider);
    });
  }
}
