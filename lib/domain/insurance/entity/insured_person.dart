import '../valobj/insurance_enums.dart';

class InsuredPerson {
  const InsuredPerson({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.createdAt,
    required this.updatedAt,
    this.relationship = MemberRelationship.other,
    this.gender = MemberGender.unknown,
    this.note,
    this.avatarPreset = MemberAvatarPreset.blue,
  });

  static const maxNoteLength = 100;

  final String id;
  final String name;
  final DateTime birthDate;
  final MemberRelationship relationship;
  final MemberGender gender;
  final String? note;
  final MemberAvatarPreset avatarPreset;
  final DateTime createdAt;
  final DateTime updatedAt;

  int ageAt(DateTime date) {
    var age = date.year - birthDate.year;
    if (date.month < birthDate.month ||
        (date.month == birthDate.month && date.day < birthDate.day)) {
      age--;
    }
    return age < 0 ? 0 : age;
  }

  void validate() {
    if (id.trim().isEmpty || name.trim().isEmpty) {
      throw ArgumentError('Insured person id and name are required.');
    }
    if (birthDate.year < 1900 || birthDate.year > 2100) {
      throw ArgumentError('Birth date is out of range.');
    }
    final normalizedNote = note?.trim();
    if (normalizedNote != null && normalizedNote.length > maxNoteLength) {
      throw ArgumentError('Member note is too long.');
    }
  }
}
