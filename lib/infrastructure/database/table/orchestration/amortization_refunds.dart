import 'package:drift/drift.dart';

@DataClassName('AmortizationRefundRow')
class AmortizationRefunds extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text().named('plan_id')();
  TextColumn get transferTransactionId =>
      text().named('transfer_transaction_id')();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['UNIQUE (transfer_transaction_id)'];
}
