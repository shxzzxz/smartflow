import 'package:drift/drift.dart';

import '../../../../domain/orchestration/valobj/amortization_enums.dart';

@DataClassName('AmortizationPlanRow')
class AmortizationPlans extends Table {
  TextColumn get id => text()();
  TextColumn get kind => textEnum<AmortizationKind>()();
  TextColumn get deferralAccountId => text().named('deferral_account_id')();
  TextColumn get categoryAccountId => text().named('category_account_id')();
  IntColumn get totalAmountMinor => integer().named('total_amount_minor')();
  TextColumn get cadenceUnit =>
      textEnum<AmortizationCadenceUnit>().named('cadence_unit')();
  IntColumn get cadenceInterval => integer().named('cadence_interval')();
  DateTimeColumn get firstRecognitionAt =>
      dateTime().named('first_recognition_at')();
  IntColumn get recognitionCount => integer().named('recognition_count')();
  BoolColumn get defaultIsExcludedFromStats => boolean()
      .named('default_is_excluded_from_stats')
      .withDefault(const Constant(false))();
  BoolColumn get defaultIsExcludedFromBudget => boolean()
      .named('default_is_excluded_from_budget')
      .withDefault(const Constant(false))();
  TextColumn get initialTransactionId =>
      text().named('initial_transaction_id')();
  TextColumn get counterpartyId => text().named('counterparty_id').nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get terminatedAt =>
      dateTime().named('terminated_at').nullable()();
  TextColumn get terminationRecognitionTransactionId =>
      text().named('termination_recognition_transaction_id').nullable()();
  TextColumn get refundTransactionId =>
      text().named('refund_transaction_id').nullable()();
  IntColumn get refundAmountMinor =>
      integer().named('refund_amount_minor').nullable()();
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
    'CHECK (recognition_count <= total_amount_minor)',
    'CHECK (refund_amount_minor IS NULL OR refund_amount_minor >= 0)',
    'CHECK ((terminated_at IS NULL AND refund_amount_minor IS NULL '
        'AND termination_recognition_transaction_id IS NULL '
        'AND refund_transaction_id IS NULL) '
        'OR terminated_at IS NOT NULL)',
  ];
}
