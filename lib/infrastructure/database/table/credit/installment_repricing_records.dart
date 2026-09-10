import 'package:drift/drift.dart';

@DataClassName('InstallmentRepricingRow')
class InstallmentRepricingRecords extends Table {
  TextColumn get id => text()();
  TextColumn get contractId => text()();
  TextColumn get stageId => text()();
  DateTimeColumn get resetDate => dateTime()();
  DateTimeColumn get effectiveDate => dateTime()();
  DateTimeColumn get referenceRateDate => dateTime()();
  TextColumn get referenceRateType => text()();
  IntColumn get referenceRatePpm => integer()();
  IntColumn get spreadBp => integer()();
  TextColumn get source => text()();
  BoolColumn get applied => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    'UNIQUE (contract_id, stage_id, reset_date)',
    "CHECK (reference_rate_type IN ('lprOneYear', 'lprFiveYearPlus', 'loanBenchmarkShortTerm', 'loanBenchmarkLongTerm'))",
    'CHECK (reference_rate_ppm >= 0 AND reference_rate_ppm + spread_bp * 100 >= 0)',
    'CHECK (reference_rate_date <= reset_date AND reset_date <= effective_date)',
  ];
}
