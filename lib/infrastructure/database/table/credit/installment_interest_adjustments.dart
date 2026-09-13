import 'package:drift/drift.dart';

@DataClassName('InstallmentInterestAdjustmentRow')
class InstallmentInterestAdjustments extends Table {
  TextColumn get id => text()();
  TextColumn get contractId => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  IntColumn get ratioPpm => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    'CHECK (ratio_ppm >= 0)',
    'CHECK (end_date > start_date)',
  ];
}
