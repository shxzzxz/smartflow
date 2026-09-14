import 'package:drift/drift.dart';

@DataClassName('InstallmentProductRow')
class InstallmentProducts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  TextColumn get dayCount => text().withDefault(const Constant('thirty360'))();
  TextColumn get rounding => text().withDefault(const Constant('halfUp'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}
