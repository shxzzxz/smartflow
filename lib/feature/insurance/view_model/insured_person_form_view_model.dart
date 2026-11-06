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

part 'insured_person_form_view_model.g.dart';

final _logger = Logger('feature.insurance.person_form');

@riverpod
class InsuredPersonFormViewModel extends _$InsuredPersonFormViewModel {
  InsuredPersonFormState? _initializedState;

  @override
  Future<InsuredPersonFormState?> build(String? personId) async {
    if (personId == null) {
      return _initializedState ??= const InsuredPersonFormState();
    }
    final people = await ref
        .watch(insuranceCoverageQueryServiceProvider)
        .listInsuredPeople();
    final person = people.where((item) => item.id == personId).firstOrNull;
    if (person == null) return null;
    return _initializedState ??= InsuredPersonFormState(
      id: person.id,
      name: person.name,
      birthDate: person.birthDate,
      relationship: person.relationship,
      gender: person.gender,
      note: person.note,
      avatarPreset: person.avatarPreset,
    );
  }

  void setBirthDate(DateTime? value) {
    _update((current) => current.copyWith(birthDate: value));
  }

  void setRelationship(MemberRelationship value) {
    _update((current) => current.copyWith(relationship: value));
  }

  void setGender(MemberGender value) {
    _update((current) => current.copyWith(gender: value));
  }

  void setAvatarPreset(MemberAvatarPreset value) {
    _update((current) => current.copyWith(avatarPreset: value));
  }

  Future<UiActionOutcome<String>> save({
    required String nameText,
    required DateTime? birthDate,
    required String noteText,
  }) async {
    final current = state.asData?.value;
    if (current == null) return _invalid('成员表单尚未加载');
    if (current.submitting) return _invalid('正在保存，请勿重复提交');
    final name = nameText.trim();
    if (name.isEmpty) return _invalid('请输入成员姓名');
    if (birthDate == null) return _invalid('请选择出生日期');
    final note = noteText.trim();
    if (note.length > InsuredPerson.maxNoteLength) {
      return _invalid('备注不能超过 ${InsuredPerson.maxNoteLength} 个字');
    }

    _update((value) => value.copyWith(submitting: true));
    try {
      final outcome = await guardUiAction(
        _logger,
        'Save insured person',
        () => ref
            .read(insuredPersonAppServiceProvider)
            .save(
              SaveInsuredPersonCommand(
                id: current.id,
                name: name,
                birthDate: birthDate,
                relationship: current.relationship,
                gender: current.gender,
                note: note,
                avatarPreset: current.avatarPreset,
              ),
            ),
      );
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

  void _update(InsuredPersonFormState Function(InsuredPersonFormState) update) {
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

class InsuredPersonFormState {
  const InsuredPersonFormState({
    this.id,
    this.name = '',
    this.birthDate,
    this.relationship = MemberRelationship.self,
    this.gender = MemberGender.unknown,
    this.note,
    this.avatarPreset = MemberAvatarPreset.blue,
    this.submitting = false,
  });

  final String? id;
  final String name;
  final DateTime? birthDate;
  final MemberRelationship relationship;
  final MemberGender gender;
  final String? note;
  final MemberAvatarPreset avatarPreset;
  final bool submitting;

  InsuredPersonFormState copyWith({
    String? id,
    String? name,
    Object? birthDate = _sentinel,
    MemberRelationship? relationship,
    MemberGender? gender,
    Object? note = _sentinel,
    MemberAvatarPreset? avatarPreset,
    bool? submitting,
  }) {
    return InsuredPersonFormState(
      id: id ?? this.id,
      name: name ?? this.name,
      birthDate: birthDate == _sentinel
          ? this.birthDate
          : birthDate as DateTime?,
      relationship: relationship ?? this.relationship,
      gender: gender ?? this.gender,
      note: note == _sentinel ? this.note : note as String?,
      avatarPreset: avatarPreset ?? this.avatarPreset,
      submitting: submitting ?? this.submitting,
    );
  }
}

const Object _sentinel = Object();
