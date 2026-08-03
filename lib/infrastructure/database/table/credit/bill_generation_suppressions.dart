import 'package:drift/drift.dart';

@DataClassName('BillGenerationSuppressionRow')
class BillGenerationSuppressions extends Table {
  TextColumn get accountId => text().named('account_id')();
  IntColumn get period => integer()();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {accountId, period};
}
