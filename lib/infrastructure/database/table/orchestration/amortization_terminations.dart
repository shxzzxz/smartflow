import 'package:drift/drift.dart';

@DataClassName('AmortizationTerminationRow')
class AmortizationTerminations extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text().named('plan_id')();
  DateTimeColumn get terminatedAt => dateTime().named('terminated_at')();
  TextColumn get recognitionTransactionId =>
      text().named('recognition_transaction_id').nullable()();
  TextColumn get returnTransactionId =>
      text().named('return_transaction_id').nullable()();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'UNIQUE (plan_id)',
    'UNIQUE (recognition_transaction_id)',
    'UNIQUE (return_transaction_id)',
    'CHECK (recognition_transaction_id IS NOT NULL '
        'OR return_transaction_id IS NOT NULL)',
  ];
}
