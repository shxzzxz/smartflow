import 'package:drift/drift.dart';

import '../../../../domain/ledger/valobj/ledger_enum.dart';

@DataClassName('EntryRow')
class Entries extends Table {
  @override
  String get tableName => 'entries';

  TextColumn get id => text()();
  TextColumn get transactionId => text().named('transaction_id')();
  TextColumn get accountId => text().named('account_id')();
  TextColumn get direction => textEnum<EntryDirection>()();
  IntColumn get amountMinor => integer().named('amount_minor')();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
