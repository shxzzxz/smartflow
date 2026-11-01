import 'package:drift/drift.dart';

@DataClassName('AmortizationEntryAllocationRow')
class AmortizationEntryAllocations extends Table {
  TextColumn get id => text()();
  TextColumn get entryId => text().named('entry_id')();
  IntColumn get lineNo => integer().named('line_no')();
  TextColumn get accountId => text().named('account_id')();
  IntColumn get amountMinor => integer().named('amount_minor')();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'UNIQUE (entry_id, line_no)',
    'UNIQUE (entry_id, account_id)',
    'CHECK (line_no > 0)',
    'CHECK (amount_minor > 0)',
  ];
}
