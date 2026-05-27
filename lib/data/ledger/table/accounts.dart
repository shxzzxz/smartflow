import 'package:drift/drift.dart';

import '../../../domain/ledger/valobj/ledger_enum.dart';

@DataClassName('AccountRow')
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get accountType => textEnum<AccountType>().named('account_type')();
  TextColumn get accountSubtype =>
      textEnum<AccountSubtype>().named('account_subtype').nullable()();
  TextColumn get parentId => text().named('parent_id').nullable()();
  IntColumn get balanceMinor =>
      integer().named('balance_minor').withDefault(const Constant(0))();
  TextColumn get iconKey => text().named('icon_key').nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get creditLimitMinor =>
      integer().named('credit_limit_minor').nullable()();
  IntColumn get billingDay => integer().named('billing_day').nullable()();
  IntColumn get repaymentDay => integer().named('repayment_day').nullable()();
  IntColumn get sortOrder =>
      integer().named('sort_order').withDefault(const Constant(0))();
  BoolColumn get isHidden =>
      boolean().named('is_hidden').withDefault(const Constant(false))();
  DateTimeColumn get archivedAt => dateTime().named('archived_at').nullable()();
  TextColumn get systemKey =>
      textEnum<SystemKey>().named('system_key').nullable()();
  TextColumn get source =>
      textEnum<AccountSource>().withDefault(
        Constant(AccountSource.user.name),
      )();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['UNIQUE (system_key)'];
}
