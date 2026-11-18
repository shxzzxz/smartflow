import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/insurance/insurance_command_api.dart';
import '../../../application/insurance/insurance_query_api.dart';
import '../../../core/money/money.dart';
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
  Future<SocialInsuranceDetailState?> build(String insuranceId) async {
    final detail = await ref
        .watch(insuranceCoverageQueryServiceProvider)
        .socialInsuranceDetail(insuranceId);
    if (detail == null) return null;
    return SocialInsuranceDetailState(
      insuranceId: detail.insurance.id,
      insuredPerson: detail.insuredPerson,
      region: detail.insurance.region,
      insuranceType: detail.insurance.insuranceType,
      participantType: detail.insurance.participantType,
      contributionRecords: detail.insurance.contributionRecords,
      createdAt: detail.insurance.createdAt,
      updatedAt: detail.insurance.updatedAt,
    );
  }

  Future<UiActionOutcome<void>> deleteInsurance() {
    return guardUiAction(_logger, 'Delete social insurance', () async {
      await ref.read(socialInsuranceAppServiceProvider).delete(insuranceId);
      _invalidateCoverage();
    });
  }

  Future<UiActionOutcome<void>> saveContributionRecord({
    String? originalPeriod,
    required int year,
    int? month,
    Money? contributionBase,
    required Money contributionAmount,
    String? note,
  }) async {
    final current = state.asData?.value;
    if (current == null) return _invalid('社保详情尚未加载');
    if (current.submitting) return _invalid('正在保存，请勿重复提交');
    final text = note?.trim();
    final record = SocialContributionRecord(
      year: year,
      month: month,
      contributionBase: contributionBase,
      contributionAmount: contributionAmount,
      note: text == null || text.isEmpty ? null : text,
    );
    try {
      record.validate();
    } on ArgumentError {
      return _invalid('请检查缴费年份、月份、基数和金额');
    }
    if (current.contributionRecords.any(
      (item) => item.period == record.period && item.period != originalPeriod,
    )) {
      return _invalid('该年份、月份已有缴费记录，请编辑已有记录');
    }
    final next = [...current.contributionRecords];
    if (originalPeriod == null) {
      next.add(record);
    } else {
      final index = next.indexWhere((item) => item.period == originalPeriod);
      if (index == -1) return _invalid('缴费记录不存在');
      next[index] = record;
    }
    return _saveContributionRecords(current, next);
  }

  Future<UiActionOutcome<void>> removeContributionRecord(String period) async {
    final current = state.asData?.value;
    if (current == null) return _invalid('社保详情尚未加载');
    if (current.submitting) return _invalid('正在保存，请勿重复提交');
    if (!current.contributionRecords.any((item) => item.period == period)) {
      return _invalid('缴费记录不存在');
    }
    return _saveContributionRecords(current, [
      for (final item in current.contributionRecords)
        if (item.period != period) item,
    ]);
  }

  Future<UiActionOutcome<void>> _saveContributionRecords(
    SocialInsuranceDetailState current,
    List<SocialContributionRecord> records,
  ) async {
    final sorted = [...records]
      ..sort((left, right) => left.period.compareTo(right.period));
    var saved = false;
    state = AsyncData(current.copyWith(submitting: true));
    try {
      final outcome = await guardUiAction<void>(
        _logger,
        'Save social contribution records',
        () async {
          await ref
              .read(socialInsuranceAppServiceProvider)
              .save(
                SaveSocialInsuranceCommand(
                  id: current.insuranceId,
                  insuredPersonId: current.insuredPersonId,
                  region: current.region,
                  insuranceType: current.insuranceType,
                  participantType: current.participantType,
                  contributionRecords: sorted,
                ),
              );
        },
      );
      saved = outcome is UiActionSuccess<void>;
      return outcome;
    } finally {
      if (ref.mounted) {
        if (saved) {
          _invalidateCoverage();
          // Writing state after invalidation would replace the refreshed list.
          ref.invalidateSelf();
        } else {
          state = AsyncData(current.copyWith(submitting: false));
        }
      }
    }
  }

  void _invalidateCoverage() {
    ref.invalidate(insuranceMembersViewModelProvider);
    ref.invalidate(insuranceOverviewViewModelProvider);
    ref.invalidate(memberCoverageViewModelProvider);
  }

  UiActionOutcome<void> _invalid(String message) => UiActionOutcome.failure(
    UiError(code: InsuranceErrorCode.invalidCommand.code, message: message),
  );
}

class SocialInsuranceDetailState {
  SocialInsuranceDetailState({
    required this.insuranceId,
    required this.insuredPerson,
    required this.region,
    required this.insuranceType,
    required this.participantType,
    required List<SocialContributionRecord> contributionRecords,
    required this.createdAt,
    required this.updatedAt,
    this.submitting = false,
  }) : contributionRecords = List.unmodifiable(contributionRecords);

  final String insuranceId;
  final InsuredPerson insuredPerson;
  String get insuredPersonId => insuredPerson.id;
  String get insuredPersonName => insuredPerson.name;
  final String region;
  final SocialInsuranceType insuranceType;
  final SocialParticipantType participantType;
  final List<SocialContributionRecord> contributionRecords;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool submitting;

  SocialInsuranceDetailState copyWith({bool? submitting}) =>
      SocialInsuranceDetailState(
        insuranceId: insuranceId,
        insuredPerson: insuredPerson,
        region: region,
        insuranceType: insuranceType,
        participantType: participantType,
        contributionRecords: contributionRecords,
        createdAt: createdAt,
        updatedAt: updatedAt,
        submitting: submitting ?? this.submitting,
      );
}
