import 'package:drift/drift.dart';

import '../../../../domain/orchestration/valobj/amortization_enums.dart';

@DataClassName('AmortizationPlanRow')
class AmortizationPlans extends Table {
  TextColumn get id => text()();
  TextColumn get kind => textEnum<AmortizationKind>()();
  TextColumn get deferralAccountId => text().named('deferral_account_id')();
  IntColumn get totalAmountMinor => integer().named('total_amount_minor')();
  TextColumn get cadenceUnit =>
      textEnum<AmortizationCadenceUnit>().named('cadence_unit')();
  IntColumn get cadenceInterval => integer().named('cadence_interval')();
  DateTimeColumn get firstRecognitionAt =>
      dateTime().named('first_recognition_at')();
  IntColumn get recognitionCount => integer().named('recognition_count')();
  TextColumn get initialTransactionId =>
      text().named('initial_transaction_id')();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (total_amount_minor > 0)',
    'CHECK (cadence_interval > 0)',
    'CHECK (recognition_count > 0)',
  ];
}
