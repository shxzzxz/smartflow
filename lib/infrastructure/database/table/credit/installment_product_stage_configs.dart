import 'package:drift/drift.dart';

/// 产品只保存可复用规则，每笔贷款的金额、期限和日期属于合同。
@DataClassName('InstallmentProductStageConfigRow')
class InstallmentProductStageConfigs extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text()();
  IntColumn get position => integer()();
  TextColumn get stageKind => text()();
  TextColumn get repaymentMethod => text().nullable()();
  IntColumn get intervalMonths => integer().nullable()();
  TextColumn get rateType => text().nullable()();
  TextColumn get ratePeriod => text().nullable()();
  TextColumn get accrual => text().nullable()();
  TextColumn get amountAlgorithm => text().nullable()();
  IntColumn get repricingCycleMonths => integer().nullable()();
  TextColumn get inPeriodRepricingPolicy => text().nullable()();
  TextColumn get tailDifference => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'UNIQUE (product_id, position)',
    'CHECK (position >= 0)',
    "CHECK (stage_kind IN ('deferment', 'repayment'))",
    'CHECK (interval_months IS NULL OR interval_months > 0)',
    "CHECK (rate_type IS NULL OR rate_type IN ('fixed', 'lprOneYear', 'lprFiveYearPlus', 'loanBenchmarkShortTerm', 'loanBenchmarkLongTerm'))",
    'CHECK (repricing_cycle_months IS NULL OR repricing_cycle_months IN (3, 6, 12))',
    "CHECK (in_period_repricing_policy IS NULL OR in_period_repricing_policy IN ('preservePrincipal', 'dynamicPeriodRate'))",
    "CHECK (tail_difference IS NULL OR tail_difference = 'lastPeriod')",
    "CHECK (stage_kind != 'deferment' OR (repayment_method IS NULL AND interval_months IS NULL AND rate_type IS NULL AND rate_period IS NULL AND accrual IS NULL AND amount_algorithm IS NULL AND repricing_cycle_months IS NULL AND in_period_repricing_policy IS NULL AND tail_difference IS NULL))",
    "CHECK (stage_kind != 'repayment' OR (repayment_method IS NOT NULL AND tail_difference IS NOT NULL))",
    "CHECK (repayment_method = 'equalInstallment' OR (amount_algorithm IS NULL AND in_period_repricing_policy IS NULL))",
    "CHECK (rate_type != 'fixed' OR repricing_cycle_months IS NULL)",
  ];
}
