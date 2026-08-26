import 'package:drift/drift.dart';

import '../../../../domain/ledger/valobj/ledger_enum.dart';

@DataClassName('TransactionRow')
class Transactions extends Table {
  @override
  String get tableName => 'transactions';

  TextColumn get id => text()();
  TextColumn get businessPurpose =>
      textEnum<BusinessPurpose>().named('business_purpose')();
  DateTimeColumn get occurredAt => dateTime().named('occurred_at')();
  DateTimeColumn get postedAt => dateTime().named('posted_at')();
  IntColumn get primaryAmountMinor => integer().named('primary_amount_minor')();
  TextColumn get counterpartyName =>
      text().named('counterparty_name').nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get parentTransactionId =>
      text().named('parent_transaction_id').nullable()();
  BoolColumn get isExcludedFromStats =>
      boolean()
          .named('is_excluded_from_stats')
          .withDefault(const Constant(false))();
  BoolColumn get isExcludedFromBudget =>
      boolean()
          .named('is_excluded_from_budget')
          .withDefault(const Constant(false))();
  TextColumn get sourceKind => textEnum<SourceKind>().named('source_kind')();
  TextColumn get ownerType => text().named('owner_type').nullable()();
  TextColumn get ownerId => text().named('owner_id').nullable()();
  TextColumn get ownerRole => text().named('owner_role').nullable()();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
