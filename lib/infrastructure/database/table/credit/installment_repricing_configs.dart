import 'package:drift/drift.dart';

@DataClassName('InstallmentRepricingConfigRow')
@TableIndex.sql('''
  CREATE INDEX installment_repricing_configs_active_idx
  ON installment_repricing_configs (contract_id) WHERE generation_completed = 0
''')
class InstallmentRepricingConfigs extends Table {
  TextColumn get id => text()();
  TextColumn get contractId => text()();
  TextColumn get stageId => text()();
  DateTimeColumn get effectiveFrom => dateTime()();
  TextColumn get referenceRateType => text()();
  IntColumn get spreadBp => integer()();
  DateTimeColumn get firstResetDate => dateTime()();
  DateTimeColumn get firstEffectiveDate => dateTime()();
  IntColumn get cycleMonths => integer()();
  DateTimeColumn get lastGeneratedDate => dateTime().nullable()();
  BoolColumn get generationCompleted =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    'UNIQUE (contract_id, stage_id, effective_from)',
    'CHECK (cycle_months IN (3, 6, 12))',
    'CHECK (first_effective_date >= first_reset_date)',
    'CHECK (last_generated_date IS NULL OR last_generated_date >= effective_from)',
    "CHECK (reference_rate_type IN ('lprOneYear', 'lprFiveYearPlus', 'loanBenchmarkShortTerm', 'loanBenchmarkLongTerm'))",
  ];
}
