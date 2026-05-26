import 'package:drift/drift.dart';

import '../../../domain/ledger/valobj/ledger_enum.dart';

@DataClassName('EntryRow')
class Entries extends Table {
  @override
  String get tableName => 'entries';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer().named('transaction_id')();
  IntColumn get accountId => integer().named('account_id')();
  TextColumn get direction => textEnum<EntryDirection>()();
  IntColumn get amountMinor => integer().named('amount_minor')();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();
}
