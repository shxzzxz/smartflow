import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/migration/v41_installment_schema.dart';

/// Restore the frozen v41 installment layout for historical upgrade fixtures.
/// Other domains keep their existing fixture setup.
Future<void> prepareLegacyInstallmentTables(AppDatabase db) async {
  final columns = await db
      .customSelect('PRAGMA table_info(installment_stage_configs)')
      .get();
  if (columns.isEmpty) return;
  if (columns.any((row) => row.read<String>('name') == 'owner_type')) return;
  final products = await db
      .customSelect('SELECT * FROM installment_product_stage_configs')
      .get();
  final contracts = await db
      .customSelect('SELECT * FROM installment_stage_configs')
      .get();
  await db.customStatement('DROP TABLE installment_stage_configs');
  await db.customStatement(legacyInstallmentStagesSql);
  for (final row in [...products, ...contracts]) {
    final product = row.data.containsKey('product_id');
    final deferment = row.data['stage_kind'] == 'deferment';
    await insertLegacyInstallmentStage(db, {
      for (final field in [
        'id',
        'position',
        'stage_kind',
        'repayment_method',
        'interval_months',
        'rate_period',
        'accrual',
        'amount_algorithm',
        'created_at',
        'updated_at',
      ])
        field: row.data[field],
      'owner_type': product ? 'product' : 'contract',
      'owner_id': row.data[product ? 'product_id' : 'contract_id'],
      if (!product) ...{
        for (final field in [
          'periods',
          'end_principal_minor',
          'fixed_amount_minor',
          'fee_minor',
          'first_date',
          'accrual_start_date',
        ])
          field: row.data[field],
        'rate_ppm': row.data['initial_rate_ppm'],
        if (deferment)
          'until_date': row.data['end_date']
        else
          'last_date': row.data['end_date'],
      },
      'repricing_payment_timing':
          switch (row.data['in_period_repricing_policy']) {
            'preservePrincipal' => 'nextPeriod',
            'dynamicPeriodRate' => 'currentPeriod',
            _ => null,
          },
    });
  }
  await db.customStatement('DROP TABLE installment_product_stage_configs');
  await db.customStatement(
    "ALTER TABLE installment_products ADD COLUMN tail_difference TEXT NOT NULL DEFAULT 'lastPeriod'",
  );
  for (final column in [
    'product_id TEXT',
    'product_name TEXT',
    'custom_rules INTEGER NOT NULL DEFAULT 0',
    "tail_difference TEXT NOT NULL DEFAULT 'lastPeriod'",
  ]) {
    await db.customStatement(
      'ALTER TABLE installment_contracts ADD COLUMN $column',
    );
  }
}

Future<void> finishLegacyInstallmentTables(AppDatabase db) async {
  final columns = await db
      .customSelect('PRAGMA table_info(installment_contracts)')
      .get();
  if (columns.any((row) => row.read<String>('name') == 'borrowing_date')) {
    await db.customStatement(
      'ALTER TABLE installment_contracts RENAME COLUMN borrowing_date TO start_date',
    );
  }
}

Future<void> insertLegacyInstallmentStage(
  AppDatabase db,
  Map<String, Object?> fields,
) => db.customStatement(
  'INSERT INTO installment_stage_configs (${fields.keys.join(', ')}) VALUES (${List.filled(fields.length, '?').join(', ')})',
  fields.values
      .map(
        (value) =>
            value is DateTime ? value.millisecondsSinceEpoch ~/ 1000 : value,
      )
      .toList(),
);
