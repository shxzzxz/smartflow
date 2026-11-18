import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/insurance/insurance_command_api.dart';
import '../../../application/insurance/insurance_query_api.dart';
import '../../shared/presentation/china_region_data.dart';
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
    if (_initializedState case final initialized?) return initialized;
    final regions = await loadChinaRegions();
    return _initializedState ??= SocialInsuranceFormState.fromDetail(
      detail,
      insuredPeople: people,
      region:
          findChinaRegionCitySelection(
            regions: regions,
            label: detail.insurance.region,
          )?.label ??
          '',
    );
  }

  void setInsuredPersonId(String value) {
    _update((current) => current.copyWith(insuredPersonId: value));
  }

  void setInsuranceType(SocialInsuranceType value) {
    _update((current) {
      if (current.typesLocked) return current;
      return current.copyWith(insuranceType: value);
    });
  }

  void setParticipantType(SocialParticipantType value) {
    _update((current) {
      if (current.typesLocked) return current;
      return current.copyWith(participantType: value);
    });
  }

  void setRegion(String value) {
    _update((current) => current.copyWith(region: value));
  }

  Future<UiActionOutcome<String>> save() async {
    final current = state.asData?.value;
    if (current == null) return _invalid('社保表单尚未加载');
    if (current.submitting) return _invalid('正在保存，请勿重复提交');
    if (current.insuredPersonId == null) return _invalid('请选择参保人');
    final region = current.region.trim();
    if (region.isEmpty) return _invalid('请选择参保地区');

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
    this.typesLocked = false,
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
    required String region,
  }) {
    return SocialInsuranceFormState(
      id: detail.insurance.id,
      insuredPeople: List.unmodifiable(insuredPeople),
      insuredPersonId: detail.insuredPerson.id,
      region: region,
      insuranceType: detail.insurance.insuranceType,
      participantType: detail.insurance.participantType,
      contributionRecords: _sorted(detail.insurance.contributionRecords),
      typesLocked: true,
    );
  }

  final String? id;
  final List<InsuredPerson> insuredPeople;
  final String? insuredPersonId;
  final String region;
  final SocialInsuranceType insuranceType;
  final SocialParticipantType participantType;
  final List<SocialContributionRecord> contributionRecords;
  final bool typesLocked;
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
    bool? typesLocked,
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
      typesLocked: typesLocked ?? this.typesLocked,
      submitting: submitting ?? this.submitting,
    );
  }
}

List<SocialContributionRecord> _sorted(List<SocialContributionRecord> records) {
  final next = [...records]
    ..sort((left, right) => left.period.compareTo(right.period));
  return List.unmodifiable(next);
}
