import 'package:drift/drift.dart';

import '../../../domain/credit/valobj/installment_plan_terms.dart';
import '../../../domain/credit/valobj/reference_rate.dart';
import '../../credit/mapper/installment_stage_mapper.dart';
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
      final contract = await (database.select(
        database.installmentContracts,
      )..where((value) => value.id.equals(contractId))).getSingleOrNull();
      if (contract == null) throw StateError('旧重定价缺少所属合同，升级已回滚');
      final stages =
          await (database.select(database.installmentStageConfigs)
                ..where(
                  (value) =>
                      value.ownerType.equals('contract') &
                      value.ownerId.equals(contractId),
                )
                ..orderBy([(value) => OrderingTerm.asc(value.position)]))
              .get();
      final terms = decodeContractTerms(
        stages,
        dayCount: contract.dayCount,
        rounding: contract.rounding,
      );
      final date = DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('effective') * 1000,
        isUtc: true,
      );
      final id = row.read<String>('id');
      String? stageId;
      for (final stage in terms.stages) {
        if (stage.terms is AmortizingStage &&
            name == 'installment_repricing_configs' &&
            id == '${stage.id}:repricing') {
          stageId = stage.id;
          break;
        }
      }
      if (stageId == null &&
          !date.isBefore(referenceDate(contract.borrowingDate))) {
        for (final stage in terms.stages) {
          if (stage.terms is AmortizingStage &&
              date.isBefore(
                terms.repaymentRange(stage.id, contract.borrowingDate).end,
              )) {
            stageId = stage.id;
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
