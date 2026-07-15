import 'package:drift/drift.dart';

import '../../../../domain/credit/valobj/bill_enums.dart';

@DataClassName('BillRow')
class Bills extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().named('account_id')();
  IntColumn get period => integer()();
  DateTimeColumn get startDate => dateTime().named('start_date').nullable()();
  DateTimeColumn get billingDate =>
      dateTime().named('billing_date').nullable()();
  DateTimeColumn get repaymentDate =>
      dateTime().named('repayment_date').nullable()();
  TextColumn get status => textEnum<BillStatus>().named('status')();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['UNIQUE (account_id, period)'];
}
