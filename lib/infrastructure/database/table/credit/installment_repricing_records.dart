import 'package:drift/drift.dart';

@DataClassName('InstallmentRepricingRow')
@TableIndex.sql('''
  CREATE INDEX installment_repricing_records_pending_idx
  ON installment_repricing_records (contract_id) WHERE status = 'pending'
''')
class InstallmentRepricingRecords extends Table {
  TextColumn get id => text()();
  TextColumn get contractId => text()();
  TextColumn get stageId => text()();
  TextColumn get pricingMethod => text()();
  DateTimeColumn get effectiveDate => dateTime()();
  IntColumn get ratePpm => integer().nullable()();
  TextColumn get ratePeriod => text().nullable()();
  DateTimeColumn get resetDate => dateTime().nullable()();
  DateTimeColumn get referenceRateDate => dateTime().nullable()();
  TextColumn get referenceRateType => text().nullable()();
  IntColumn get referenceRatePpm => integer().nullable()();
  IntColumn get spreadBp => integer().nullable()();
  TextColumn get source => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    'UNIQUE (contract_id, stage_id, effective_date)',
    "CHECK (pricing_method IN ('direct', 'reference'))",
    "CHECK ((pricing_method = 'direct' "
        'AND rate_ppm IS NOT NULL AND rate_period IS NOT NULL '
        'AND reset_date IS NULL AND reference_rate_date IS NULL '
        'AND reference_rate_type IS NULL AND reference_rate_ppm IS NULL '
        'AND spread_bp IS NULL AND source IS NULL) '
        "OR (pricing_method = 'reference' "
        'AND rate_ppm IS NULL AND rate_period IS NULL '
        'AND reset_date IS NOT NULL AND reference_rate_date IS NOT NULL '
        'AND reference_rate_type IS NOT NULL AND reference_rate_ppm IS NOT NULL '
        'AND spread_bp IS NOT NULL AND source IS NOT NULL))',
    'CHECK (rate_ppm >= 0)',
    "CHECK (rate_period IN ('annual', 'monthly', 'daily'))",
    "CHECK (status IN ('pending', 'applied', 'userConfirmed'))",
    "CHECK (reference_rate_type IN ('lprOneYear', 'lprFiveYearPlus', 'loanBenchmarkShortTerm', 'loanBenchmarkLongTerm'))",
    'CHECK (reference_rate_ppm >= 0 AND reference_rate_ppm + spread_bp * 100 >= 0)',
    'CHECK (reference_rate_date <= reset_date AND reset_date <= effective_date)',
  ];
}
