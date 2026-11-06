import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/insurance/insurance_command_api.dart';
import '../../../application/insurance/insurance_query_api.dart';
import '../../../core/money/money.dart';
import '../../../core/time/month_key.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import 'insurance_members_view_model.dart';
import 'insurance_overview_view_model.dart';
import 'member_coverage_view_model.dart';

part 'social_insurance_detail_view_model.g.dart';

final _logger = Logger('feature.insurance.social_detail');

@riverpod
class SocialInsuranceDetailViewModel extends _$SocialInsuranceDetailViewModel {
  @override
  Future<SocialInsuranceDetailState?> build(
    String insuranceId,
    InsuranceSourceType sourceType,
  ) async {
    final query = ref.watch(insuranceCoverageQueryServiceProvider);
    return switch (sourceType) {
      InsuranceSourceType.commercial => null,
      InsuranceSourceType.socialMedical => _fromMedical(
        await query.socialMedicalInsuranceDetail(insuranceId),
      ),
      InsuranceSourceType.socialPension => _fromPension(
        await query.socialPensionInsuranceDetail(insuranceId),
      ),
    };
  }

  Future<UiActionOutcome<void>> deleteInsurance() {
    return guardUiAction(_logger, 'Delete social insurance', () async {
      final service = ref.read(socialInsuranceAppServiceProvider);
      switch (sourceType) {
        case InsuranceSourceType.socialMedical:
          await service.deleteMedical(insuranceId);
        case InsuranceSourceType.socialPension:
          await service.deletePension(insuranceId);
        case InsuranceSourceType.commercial:
          throw StateError('Commercial insurance is not a social record.');
      }
      ref.invalidate(insuranceMembersViewModelProvider);
      ref.invalidate(insuranceOverviewViewModelProvider);
      ref.invalidate(memberCoverageViewModelProvider);
    });
  }

  Future<UiActionOutcome<void>> addContributionRecord(
    MonthKey month,
    Money contributionBase,
  ) async {
    final current = state.asData?.value;
    if (current == null) return _invalid('社保详情尚未加载');
    if (contributionBase.minorUnits < 0) return _invalid('缴费基数不能为负');
    if (current.contributionRecords.any((item) => item.month == month)) {
      return _invalid('该月份已有缴费记录，请编辑已有记录');
    }
    return _saveContributionRecords(current, [
      ...current.contributionRecords,
      SocialContributionRecord(
        month: month,
        contributionBase: contributionBase,
      ),
    ]);
  }

  Future<UiActionOutcome<void>> updateContributionRecord({
    required MonthKey originalMonth,
    required MonthKey month,
    required Money contributionBase,
  }) async {
    final current = state.asData?.value;
    if (current == null) return _invalid('社保详情尚未加载');
    if (contributionBase.minorUnits < 0) return _invalid('缴费基数不能为负');
    if (current.contributionRecords.any(
      (item) => item.month == month && item.month != originalMonth,
    )) {
      return _invalid('该月份已有缴费记录');
    }
    final index = current.contributionRecords.indexWhere(
      (item) => item.month == originalMonth,
    );
    if (index == -1) return _invalid('缴费记录不存在');
    final next = [...current.contributionRecords];
    next[index] = SocialContributionRecord(
      month: month,
      contributionBase: contributionBase,
    );
    return _saveContributionRecords(current, next);
  }

  Future<UiActionOutcome<void>> removeContributionRecord(MonthKey month) async {
    final current = state.asData?.value;
    if (current == null) return _invalid('社保详情尚未加载');
    if (!current.contributionRecords.any((item) => item.month == month)) {
      return _invalid('缴费记录不存在');
    }
    return _saveContributionRecords(current, [
      for (final item in current.contributionRecords)
        if (item.month != month) item,
    ]);
  }

  Future<UiActionOutcome<void>> _saveContributionRecords(
    SocialInsuranceDetailState current,
    List<SocialContributionRecord> records,
  ) async {
    final sortedRecords = List<SocialContributionRecord>.unmodifiable(
      [...records]..sort((left, right) => left.month.compareTo(right.month)),
    );
    final outcome = await guardUiAction<void>(
      _logger,
      'Save social contribution records',
      () async {
        final command = SaveSocialInsuranceCommand(
          id: current.insuranceId,
          insuredPersonId: current.insuredPersonId,
          region: current.region,
          participantType: current.participantType,
          contributionRecords: sortedRecords,
        );
        final service = ref.read(socialInsuranceAppServiceProvider);
        switch (sourceType) {
          case InsuranceSourceType.socialMedical:
            await service.saveMedical(command);
          case InsuranceSourceType.socialPension:
            await service.savePension(command);
          case InsuranceSourceType.commercial:
            throw StateError('Commercial insurance is not a social record.');
        }
      },
    );
    if (outcome is UiActionSuccess<void> && ref.mounted) {
      state = AsyncData(
        SocialInsuranceDetailState(
          insuranceId: current.insuranceId,
          insuredPersonId: current.insuredPersonId,
          insuredPersonName: current.insuredPersonName,
          region: current.region,
          participantType: current.participantType,
          contributionRecords: sortedRecords,
          createdAt: current.createdAt,
          updatedAt: current.updatedAt,
        ),
      );
      ref.invalidate(insuranceMembersViewModelProvider);
      ref.invalidate(insuranceOverviewViewModelProvider);
      ref.invalidate(memberCoverageViewModelProvider);
    }
    return outcome;
  }

  UiActionOutcome<void> _invalid(String message) {
    return UiActionOutcome.failure(
      UiError(code: InsuranceErrorCode.invalidCommand.code, message: message),
    );
  }

  SocialInsuranceDetailState? _fromMedical(
    SocialMedicalInsuranceDetail? detail,
  ) {
    if (detail == null) return null;
    return SocialInsuranceDetailState(
      insuranceId: detail.insurance.id,
      insuredPersonId: detail.insuredPerson.id,
      insuredPersonName: detail.insuredPerson.name,
      region: detail.insurance.region,
      participantType: detail.insurance.participantType,
      contributionRecords: detail.insurance.contributionRecords,
      createdAt: detail.insurance.createdAt,
      updatedAt: detail.insurance.updatedAt,
    );
  }

  SocialInsuranceDetailState? _fromPension(
    SocialPensionInsuranceDetail? detail,
  ) {
    if (detail == null) return null;
    return SocialInsuranceDetailState(
      insuranceId: detail.insurance.id,
      insuredPersonId: detail.insuredPerson.id,
      insuredPersonName: detail.insuredPerson.name,
      region: detail.insurance.region,
      participantType: detail.insurance.participantType,
      contributionRecords: detail.insurance.contributionRecords,
      createdAt: detail.insurance.createdAt,
      updatedAt: detail.insurance.updatedAt,
    );
  }
}

class SocialInsuranceDetailState {
  const SocialInsuranceDetailState({
    required this.insuranceId,
    required this.insuredPersonId,
    required this.insuredPersonName,
    required this.region,
    required this.participantType,
    required this.contributionRecords,
    required this.createdAt,
    required this.updatedAt,
  });

  final String insuranceId;
  final String insuredPersonId;
  final String insuredPersonName;
  final String region;
  final SocialParticipantType participantType;
  final List<SocialContributionRecord> contributionRecords;
  final DateTime createdAt;
  final DateTime updatedAt;
}
