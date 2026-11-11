import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/insurance/insurance_command_api.dart';
import '../../../application/insurance/insurance_query_api.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import 'insurance_members_view_model.dart';
import 'insurance_overview_view_model.dart';
import 'member_coverage_view_model.dart';

part 'social_insurance_form_view_model.g.dart';

final _logger = Logger('feature.insurance.social_form');

@riverpod
class SocialInsuranceFormViewModel extends _$SocialInsuranceFormViewModel {
  SocialInsuranceFormState? _initializedState;

  @override
  Future<SocialInsuranceFormState?> build(
    String? insuranceId,
    String? initialInsuredPersonId,
  ) async {
    final query = ref.watch(insuranceCoverageQueryServiceProvider);
    final people = await query.listInsuredPeople();
    if (insuranceId == null) {
      final initialPerson = people
          .where((item) => item.id == initialInsuredPersonId)
          .firstOrNull;
      return _initializedState ??= SocialInsuranceFormState.initial(
        insuredPeople: people,
        initialInsuredPersonId:
            initialPerson?.id ?? (people.length == 1 ? people.single.id : null),
      );
    }

    final detail = await query.socialInsuranceDetail(insuranceId);
    if (detail == null) return null;
    return _initializedState ??= SocialInsuranceFormState.fromDetail(
      detail,
      insuredPeople: people,
    );
  }

  void setInsuredPersonId(String value) {
    _update((current) {
      if (current.identityLocked) return current;
      return current.copyWith(insuredPersonId: value);
    });
  }

  void setInsuranceType(SocialInsuranceType value) {
    _update((current) {
      if (current.identityLocked) return current;
      return current.copyWith(insuranceType: value);
    });
  }

  void setParticipantType(SocialParticipantType value) {
    _update((current) {
      if (current.identityLocked) return current;
      return current.copyWith(participantType: value);
    });
  }

  Future<UiActionOutcome<String>> save({required String regionText}) async {
    final current = state.asData?.value;
    if (current == null) return _invalid('社保表单尚未加载');
    if (current.submitting) return _invalid('正在保存，请勿重复提交');
    if (current.insuredPersonId == null) return _invalid('请选择参保人');
    final region = regionText.trim();
    if (region.isEmpty) return _invalid('请输入参保地区');

    _update((value) => value.copyWith(submitting: true));
    try {
      final outcome = await guardUiAction(_logger, 'Save social insurance', () {
        return ref
            .read(socialInsuranceAppServiceProvider)
            .save(
              SaveSocialInsuranceCommand(
                id: current.id,
                insuredPersonId: current.insuredPersonId!,
                region: region,
                insuranceType: current.insuranceType,
                participantType: current.participantType,
                contributionRecords: current.contributionRecords,
              ),
            );
      });
      if (outcome is UiActionSuccess<String>) {
        ref.invalidate(insuranceMembersViewModelProvider);
        ref.invalidate(insuranceOverviewViewModelProvider);
        ref.invalidate(memberCoverageViewModelProvider);
      }
      return outcome;
    } finally {
      if (ref.mounted) {
        _update((latest) => latest.copyWith(submitting: false));
      }
    }
  }

  void _update(
    SocialInsuranceFormState Function(SocialInsuranceFormState) update,
  ) {
    final current = state.asData?.value;
    if (current == null) return;
    final next = update(current);
    _initializedState = next;
    state = AsyncData(next);
  }

  UiActionOutcome<String> _invalid(String message) {
    return UiActionOutcome.failure(
      UiError(code: InsuranceErrorCode.invalidCommand.code, message: message),
    );
  }
}

class SocialInsuranceFormState {
  SocialInsuranceFormState({
    required this.insuredPeople,
    required this.insuranceType,
    required this.participantType,
    required List<SocialContributionRecord> contributionRecords,
    this.id,
    this.insuredPersonId,
    this.region = '',
    this.identityLocked = false,
    this.submitting = false,
  }) : contributionRecords = List.unmodifiable(contributionRecords);

  factory SocialInsuranceFormState.initial({
    required List<InsuredPerson> insuredPeople,
    String? initialInsuredPersonId,
  }) {
    return SocialInsuranceFormState(
      insuredPeople: List.unmodifiable(insuredPeople),
      insuredPersonId: initialInsuredPersonId,
      insuranceType: SocialInsuranceType.medical,
      participantType: SocialParticipantType.employee,
      contributionRecords: const [],
    );
  }

  factory SocialInsuranceFormState.fromDetail(
    SocialInsuranceDetail detail, {
    required List<InsuredPerson> insuredPeople,
  }) {
    return SocialInsuranceFormState(
      id: detail.insurance.id,
      insuredPeople: List.unmodifiable(insuredPeople),
      insuredPersonId: detail.insuredPerson.id,
      region: detail.insurance.region,
      insuranceType: detail.insurance.insuranceType,
      participantType: detail.insurance.participantType,
      contributionRecords: _sorted(detail.insurance.contributionRecords),
      identityLocked: true,
    );
  }

  final String? id;
  final List<InsuredPerson> insuredPeople;
  final String? insuredPersonId;
  final String region;
  final SocialInsuranceType insuranceType;
  final SocialParticipantType participantType;
  final List<SocialContributionRecord> contributionRecords;
  final bool identityLocked;
  final bool submitting;

  InsuredPerson? get insuredPerson =>
      insuredPeople.where((person) => person.id == insuredPersonId).firstOrNull;

  SocialInsuranceFormState copyWith({
    String? id,
    String? insuredPersonId,
    String? region,
    SocialInsuranceType? insuranceType,
    SocialParticipantType? participantType,
    List<SocialContributionRecord>? contributionRecords,
    bool? identityLocked,
    bool? submitting,
  }) {
    return SocialInsuranceFormState(
      id: id ?? this.id,
      insuredPeople: insuredPeople,
      insuredPersonId: insuredPersonId ?? this.insuredPersonId,
      region: region ?? this.region,
      insuranceType: insuranceType ?? this.insuranceType,
      participantType: participantType ?? this.participantType,
      contributionRecords: contributionRecords ?? this.contributionRecords,
      identityLocked: identityLocked ?? this.identityLocked,
      submitting: submitting ?? this.submitting,
    );
  }
}

List<SocialContributionRecord> _sorted(List<SocialContributionRecord> records) {
  final next = [...records]
    ..sort((left, right) => left.month.compareTo(right.month));
  return List.unmodifiable(next);
}
