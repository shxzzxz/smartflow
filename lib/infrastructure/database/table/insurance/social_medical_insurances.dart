import 'package:drift/drift.dart';

import '../../../../domain/insurance/valobj/insurance_enums.dart';

@DataClassName('SocialMedicalInsuranceRow')
class SocialMedicalInsurances extends Table {
  TextColumn get id => text()();
  TextColumn get insuredPersonId => text().named('insured_person_id')();
  TextColumn get region => text()();
  TextColumn get participantType =>
      textEnum<SocialParticipantType>().named('participant_type')();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ["CHECK (length(trim(region)) > 0)"];
}
