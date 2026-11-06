import 'package:drift/drift.dart';

import '../../../../domain/insurance/valobj/insurance_enums.dart';

@DataClassName('InsuredPersonRow')
class InsuredPeople extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get birthDate => dateTime().named('birth_date')();
  TextColumn get relationship => textEnum<MemberRelationship>().withDefault(
    Constant(MemberRelationship.other.name),
  )();
  TextColumn get gender => textEnum<MemberGender>().withDefault(
    Constant(MemberGender.unknown.name),
  )();
  TextColumn get note => text().nullable()();
  TextColumn get avatarPreset => textEnum<MemberAvatarPreset>()
      .named('avatar_preset')
      .withDefault(Constant(MemberAvatarPreset.blue.name))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ["CHECK (length(trim(name)) > 0)"];
}
