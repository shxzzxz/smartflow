import 'package:drift/drift.dart';

@DataClassName('InstallmentStageConfigRow')
class InstallmentStageConfigs extends Table {
  TextColumn get id => text()();
  TextColumn get ownerType => text()();
  TextColumn get ownerId => text()();
  IntColumn get position => integer()();
  TextColumn get stageKind => text()();
  TextColumn get repaymentMethod => text().nullable()();
  IntColumn get intervalMonths => integer().nullable()();
  TextColumn get ratePeriod => text().nullable()();
  TextColumn get accrual => text().nullable()();
  TextColumn get amountAlgorithm => text().nullable()();
  IntColumn get periods => integer().nullable()();
  IntColumn get ratePpm => integer().nullable()();
  IntColumn get endPrincipalMinor => integer().nullable()();
  IntColumn get fixedAmountMinor => integer().nullable()();
  IntColumn get feeMinor => integer().nullable()();
  DateTimeColumn get untilDate => dateTime().nullable()();
  DateTimeColumn get firstDate => dateTime().nullable()();
  DateTimeColumn get lastDate => dateTime().nullable()();
  DateTimeColumn get accrualStartDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    "CHECK (owner_type IN ('product', 'contract'))",
    "CHECK (stage_kind IN ('deferment', 'repayment'))",
    'CHECK (position >= 0)',
    'UNIQUE (owner_type, owner_id, position)',
    'CHECK (interval_months IS NULL OR interval_months > 0)',
    'CHECK (periods IS NULL OR periods > 0)',
    'CHECK (rate_ppm IS NULL OR rate_ppm >= 0)',
    'CHECK (end_principal_minor IS NULL OR end_principal_minor >= 0)',
    'CHECK (fee_minor IS NULL OR fee_minor >= 0)',
    'CHECK (fixed_amount_minor IS NULL OR fixed_amount_minor > 0)',
    "CHECK (owner_type != 'product' OR (periods IS NULL AND rate_ppm IS NULL "
        'AND end_principal_minor IS NULL AND fixed_amount_minor IS NULL '
        'AND fee_minor IS NULL AND until_date IS NULL AND first_date IS NULL '
        'AND last_date IS NULL AND accrual_start_date IS NULL))',
    "CHECK (stage_kind != 'deferment' OR (repayment_method IS NULL "
        'AND interval_months IS NULL AND rate_period IS NULL AND accrual IS NULL '
        'AND amount_algorithm IS NULL AND periods IS NULL AND rate_ppm IS NULL '
        'AND end_principal_minor IS NULL AND fixed_amount_minor IS NULL '
        'AND fee_minor IS NULL AND first_date IS NULL AND last_date IS NULL '
        'AND accrual_start_date IS NULL))',
    "CHECK (stage_kind != 'repayment' OR (repayment_method IS NOT NULL AND until_date IS NULL))",
    "CHECK (repayment_method = 'equalInstallment' OR (amount_algorithm IS NULL AND fixed_amount_minor IS NULL))",
  ];
}
