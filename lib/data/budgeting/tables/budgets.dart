import 'package:drift/drift.dart';

@DataClassName('BudgetRow')
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get monthKey => integer().named('month_key')();
  IntColumn get accountId => integer().named('account_id').nullable()();
  IntColumn get amountMinor => integer().named('amount_minor')();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => ['CHECK (amount_minor >= 0)'];
}
