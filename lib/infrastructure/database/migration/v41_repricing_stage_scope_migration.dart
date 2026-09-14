import 'package:drift/drift.dart';

import '../../../domain/credit/valobj/reference_rate.dart';
import 'v41_installment_schema.dart';
import '../app_database.dart';

/// v40 曾移除阶段归属；保留可识别的原阶段，其余按合同条款的时间范围回填。
Future<void> migrateRepricingStageScope(
  AppDatabase database,
  Migrator migrator,
) => database.transaction(() async {
  for (final (table, dateColumn) in <(TableInfo<Table, dynamic>, String)>[
    (database.installmentRepricingConfigs, 'effective_from'),
    (database.installmentRepricingRecords, 'effective_date'),
  ]) {
    final name = table.actualTableName;
    final columns = await database
        .customSelect('PRAGMA table_info($name)')
        .get();
    if (columns.any((row) => row.read<String>('name') == 'stage_id')) continue;
    await database.customStatement(
      'ALTER TABLE $name ADD COLUMN stage_id TEXT',
    );
    final rows = await database
        .customSelect(
          'SELECT id, contract_id, $dateColumn AS effective FROM $name',
        )
        .get();
    for (final row in rows) {
      final contractId = row.read<String>('contract_id');
      final contract = await database
          .customSelect(
            'SELECT * FROM installment_contracts WHERE id = ?',
            variables: [Variable<String>(contractId)],
          )
          .getSingleOrNull();
      if (contract == null) throw StateError('旧重定价缺少所属合同，升级已回滚');
      final stages = await database
          .customSelect(
            "SELECT * FROM installment_stage_configs WHERE owner_type = 'contract' AND owner_id = ? AND stage_kind = 'repayment' ORDER BY position",
            variables: [Variable<String>(contractId)],
          )
          .get();
      final date = DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('effective') * 1000,
        isUtc: true,
      );
      final id = row.read<String>('id');
      String? stageId;
      for (final stage in stages) {
        if (name == 'installment_repricing_configs' &&
            id == '${stage.read<String>('id')}:repricing') {
          stageId = stage.read<String>('id');
          break;
        }
      }
      if (stageId == null &&
          !date.isBefore(
            referenceDate(legacyInstallmentDate(contract, 'start_date')),
          )) {
        for (final stage in stages) {
          if (date.isBefore(referenceDate(legacyInstallmentStageEnd(stage)))) {
            stageId = stage.read<String>('id');
            break;
          }
        }
      }
      if (stageId == null) throw StateError('旧重定价无法确定所属阶段，升级已回滚');
      await database.customStatement(
        'UPDATE $name SET stage_id = ? WHERE id = ?',
        [stageId, id],
      );
    }
    await migrator.alterTable(TableMigration(table));
  }
});
