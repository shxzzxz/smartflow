import '../../../../domain/insurance/valobj/insurance_enums.dart';

class SaveInsuredPersonCommand {
  const SaveInsuredPersonCommand({
    this.id,
    required this.name,
    required this.birthDate,
    required this.relationship,
    required this.gender,
    required this.avatarPreset,
    this.note,
  });

  final String? id;
  final String name;
  final DateTime birthDate;
  final MemberRelationship relationship;
  final MemberGender gender;
  final String? note;
  final MemberAvatarPreset avatarPreset;
}
