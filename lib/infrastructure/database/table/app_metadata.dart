import 'package:drift/drift.dart';

@DataClassName('AppMetadataRow')
class AppMetadata extends Table {
  TextColumn get key => text().withLength(min: 1, max: 120)();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
