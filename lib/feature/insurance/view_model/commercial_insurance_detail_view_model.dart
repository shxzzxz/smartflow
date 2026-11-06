import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/insurance/insurance_query_api.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import 'commercial_insurance_list_view_model.dart';
import 'insurance_members_view_model.dart';
import 'insurance_overview_view_model.dart';
import 'member_coverage_view_model.dart';

part 'commercial_insurance_detail_view_model.g.dart';

final _logger = Logger('feature.insurance.commercial_detail');

@riverpod
class CommercialInsuranceDetailViewModel
    extends _$CommercialInsuranceDetailViewModel {
  @override
  Future<CommercialInsuranceDetail?> build(String insuranceId) {
    return ref
        .watch(insuranceCoverageQueryServiceProvider)
        .commercialInsuranceDetail(insuranceId);
  }

  Future<UiActionOutcome<int>> addAttachments() {
    return guardUiAction(_logger, 'Add insurance attachments', () async {
      final count = await ref
          .read(commercialInsuranceAppServiceProvider)
          .addAttachments(insuranceId);
      if (count > 0) {
        ref.invalidateSelf();
        ref.invalidate(memberCoverageViewModelProvider);
      }
      return count;
    });
  }

  Future<UiActionOutcome<void>> openAttachment(String attachmentId) {
    return guardUiAction(_logger, 'Open insurance attachment', () {
      return ref
          .read(commercialInsuranceAppServiceProvider)
          .openAttachment(insuranceId: insuranceId, attachmentId: attachmentId);
    });
  }

  Future<UiActionOutcome<void>> deleteAttachment(String attachmentId) {
    return guardUiAction(_logger, 'Delete insurance attachment', () async {
      await ref
          .read(commercialInsuranceAppServiceProvider)
          .deleteAttachment(
            insuranceId: insuranceId,
            attachmentId: attachmentId,
          );
      ref.invalidateSelf();
      ref.invalidate(memberCoverageViewModelProvider);
    });
  }

  Future<UiActionOutcome<void>> deleteInsurance() {
    return guardUiAction(_logger, 'Delete commercial insurance', () async {
      await ref.read(commercialInsuranceAppServiceProvider).delete(insuranceId);
      ref.invalidate(insuranceMembersViewModelProvider);
      ref.invalidate(insuranceOverviewViewModelProvider);
      ref.invalidate(commercialInsuranceListViewModelProvider);
      ref.invalidate(memberCoverageViewModelProvider);
    });
  }
}
