import 'package:drift/drift.dart';

import '../../../domain/credit/valobj/repayment_dates_strategy.dart';

// Historical upgrade steps use their original storage shape, independently of
// the tables registered by the current application.
const legacyInstallmentProductsSql = '''
CREATE TABLE installment_products (
  id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL,
  archived INTEGER NOT NULL DEFAULT 0,
  day_count TEXT NOT NULL DEFAULT 'thirty360',
  rounding TEXT NOT NULL DEFAULT 'halfUp',
  tail_difference TEXT NOT NULL DEFAULT 'lastPeriod',
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP)),
  updated_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP))
)
''';

const legacyInstallmentStagesSql = '''
CREATE TABLE installment_stage_configs (
  id TEXT NOT NULL PRIMARY KEY, owner_type TEXT NOT NULL,
  owner_id TEXT NOT NULL, position INTEGER NOT NULL, stage_kind TEXT NOT NULL,
  repayment_method TEXT, interval_months INTEGER, rate_period TEXT,
  accrual TEXT, amount_algorithm TEXT, periods INTEGER, rate_ppm INTEGER,
  reference_rate_type TEXT, spread_bp INTEGER, first_reset_date INTEGER,
  first_effective_date INTEGER, repricing_cycle_months INTEGER,
  repricing_payment_timing TEXT, end_principal_minor INTEGER,
  fixed_amount_minor INTEGER, fee_minor INTEGER, until_date INTEGER,
  first_date INTEGER, last_date INTEGER, accrual_start_date INTEGER,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP)),
  updated_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP)),
  UNIQUE (owner_type, owner_id, position)
)
''';

DateTime legacyInstallmentDate(QueryRow row, String field) =>
    DateTime.fromMillisecondsSinceEpoch(row.read<int>(field) * 1000);

DateTime legacyInstallmentStageEnd(QueryRow row) {
  if (row.read<String>('stage_kind') == 'deferment') {
    return legacyInstallmentDate(row, 'until_date');
  }
  final dates = IntervalRepaymentDates(
    firstDate: legacyInstallmentDate(row, 'first_date'),
    count: row.read<int>('periods'),
    intervalMonths: row.readNullable<int>('interval_months') ?? 1,
    lastDate: row.readNullable<int>('last_date') == null
        ? null
        : legacyInstallmentDate(row, 'last_date'),
  ).getDates();
  for (var i = 1; i < dates.length; i++) {
    if (!dates[i].isAfter(dates[i - 1])) {
      throw StateError('旧合同阶段日期不递增，升级已回滚');
    }
  }
  return dates.last;
}

String migrateInPeriodRepricingPolicy(String? value) => switch (value) {
  null || 'nextPeriod' || 'preservePrincipal' => 'preservePrincipal',
  'currentPeriod' || 'dynamicPeriodRate' => 'dynamicPeriodRate',
  _ => throw StateError('旧期中重定价策略无效，升级已回滚'),
};
