import 'package:drift/drift.dart';

@DataClassName('InstallmentRefundReductionRow')
class InstallmentRefundReductions extends Table {
  TextColumn get id => text()();
  TextColumn get contractId => text().named('contract_id')();
  TextColumn get refundTransactionId => text().named('refund_transaction_id')();
  IntColumn get principalMinor => integer().named('principal_minor')();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'UNIQUE(refund_transaction_id)',
    'CHECK (principal_minor > 0)',
  ];
}
