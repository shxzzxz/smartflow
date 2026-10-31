import 'package:drift/drift.dart';

@DataClassName('AmortizationEntryRow')
class AmortizationEntries extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text().named('plan_id')();
  IntColumn get sequenceNo => integer().named('sequence_no')();
  DateTimeColumn get dueAt => dateTime().named('due_at')();
  IntColumn get amountMinor => integer().named('amount_minor')();
  TextColumn get transactionId => text().named('transaction_id').nullable()();
  DateTimeColumn get canceledAt => dateTime().named('canceled_at').nullable()();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'UNIQUE (plan_id, sequence_no)',
    'UNIQUE (transaction_id)',
    'CHECK (sequence_no > 0)',
    'CHECK (amount_minor > 0)',
  ];
}
