import 'package:drift/drift.dart';

import 'v41_installment_schema.dart';
import '../../../domain/credit/valobj/reference_rate.dart';
import '../app_database.dart';

/// 把阶段配置升级为独立历史，保留阶段归属。冲突利率事实使事务回滚。
Future<void> migrateInstallmentOperations(
  AppDatabase database,
  Migrator migrator,
) => database.transaction(() async {
  final existingTables = {
    for (final row
        in await database
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
            .get())
      row.read<String>('name'),
  };
  for (final table in <TableInfo<Table, dynamic>>[
    database.installmentRepricingConfigs,
    database.installmentInterestAdjustments,
  ]) {
    if (!existingTables.contains(table.actualTableName)) {
      await migrator.createTable(table);
    }
  }
  final contracts = await database
      .customSelect('SELECT * FROM installment_contracts')
      .get();
  for (final contract in contracts) {
    final contractId = contract.read<String>('id');
    final stages = await database
        .customSelect(
          "SELECT * FROM installment_stage_configs WHERE owner_type = 'contract' AND owner_id = ? ORDER BY position",
          variables: [Variable<String>(contractId)],
        )
        .get();
    var start = legacyInstallmentDate(contract, 'start_date');
    for (final stage in stages) {
      if (stage.read<String>('stage_kind') == 'deferment') {
        start = legacyInstallmentStageEnd(stage);
        continue;
      }
      final rateType = stage.readNullable<String>('reference_rate_type');
      if (rateType != null) {
        final stageId = stage.read<String>('id');
        await database
            .into(database.installmentRepricingConfigs)
            .insert(
              InstallmentRepricingConfigsCompanion.insert(
                id: '$stageId:repricing',
                contractId: contractId,
                stageId: stageId,
                effectiveFrom: referenceDate(
                  stage.readNullable<int>('accrual_start_date') == null
                      ? start
                      : legacyInstallmentDate(stage, 'accrual_start_date'),
                ),
                referenceRateType: rateType,
                spreadBp: stage.read<int>('spread_bp'),
                firstResetDate: referenceDate(
                  legacyInstallmentDate(stage, 'first_reset_date'),
                ),
                firstEffectiveDate: referenceDate(
                  legacyInstallmentDate(stage, 'first_effective_date'),
                ),
                cycleMonths: stage.read<int>('repricing_cycle_months'),
                createdAt: Value(legacyInstallmentDate(stage, 'created_at')),
              ),
            );
      }
      start = legacyInstallmentStageEnd(stage);
    }
  }
  await mergeLegacyRepricingRecords(database);
  await migrator.alterTable(
    TableMigration(database.installmentRepricingRecords),
  );
  await database.customStatement('''
    UPDATE installment_repricing_configs AS config
    SET last_generated_date = (
      SELECT MAX(record.effective_date) FROM installment_repricing_records record
      WHERE record.contract_id = config.contract_id
        AND record.stage_id = config.stage_id
        AND record.effective_date >= config.effective_from
        AND NOT EXISTS (
          SELECT 1 FROM installment_repricing_configs next
          WHERE next.contract_id = config.contract_id
            AND next.stage_id = config.stage_id
            AND next.effective_from > config.effective_from
            AND next.effective_from <= record.effective_date
        )
    )
  ''');
  await database.customStatement('''
    UPDATE installment_stage_configs SET reference_rate_type = NULL, spread_bp = NULL,
      first_reset_date = NULL, first_effective_date = NULL, repricing_cycle_months = NULL
  ''');
  await migrator.alterTable(TableMigration(database.billItems));
});

Future<void> mergeLegacyRepricingRecords(AppDatabase database) async {
  final columns = {
    for (final row
        in await database
            .customSelect('PRAGMA table_info(installment_repricing_records)')
            .get())
      row.read<String>('name'),
  };
  final fields = [
    'reset_date',
    columns.contains('tenor') ? 'tenor' : 'reference_rate_type',
    columns.contains('quote_date') ? 'quote_date' : 'reference_rate_date',
    columns.contains('lpr_ppm') ? 'lpr_ppm' : 'reference_rate_ppm',
    'spread_bp',
    'source',
  ];
  final stageScope = columns.contains('stage_id')
      ? 'AND a.stage_id = b.stage_id '
      : '';
  final conflict = await database
      .customSelect(
        'SELECT 1 FROM installment_repricing_records a JOIN installment_repricing_records b '
        'ON a.contract_id = b.contract_id AND a.effective_date = b.effective_date AND a.id < b.id $stageScope'
        'WHERE ${fields.map((field) => 'a.$field != b.$field').join(' OR ')} LIMIT 1',
      )
      .get();
  if (conflict.isNotEmpty) throw StateError('同一合同同一阶段同一生效日存在冲突的旧重定价快照，升级已回滚');
  final ordering = columns.contains('status')
      ? "CASE status WHEN 'userConfirmed' THEN 0 WHEN 'applied' THEN 1 ELSE 2 END"
      : 'CASE applied WHEN 1 THEN 0 ELSE 1 END';
  await database.customStatement(
    'DELETE FROM installment_repricing_records WHERE id IN ('
    'SELECT id FROM (SELECT id, ROW_NUMBER() OVER (PARTITION BY contract_id, '
    '${columns.contains('stage_id') ? 'stage_id, ' : ''}effective_date '
    'ORDER BY $ordering, id) AS position FROM installment_repricing_records) WHERE position > 1)',
  );
}
