import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/import/import_models.dart';
import 'package:smartflow/domain/import/import_persistence_models.dart';
import 'package:smartflow/infrastructure/import/repository/drift_import_batch_repository.dart';
import 'package:smartflow/infrastructure/import/repository/drift_import_mapping_repository.dart';

import '../../helper/test_app_database.dart';

void main() {
  test(
    'schema contains the three import tables without foreign keys',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);

      final version = await database
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 33);

      for (final table in [
        'import_entity_mappings',
        'import_batches',
        'import_batch_items',
      ]) {
        final rows = await database
            .customSelect('PRAGMA foreign_key_list($table)')
            .get();
        expect(rows, isEmpty, reason: '$table must not declare foreign keys');
      }
    },
  );

  test('mapping upsert keeps one current default per source entity', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final repository = DriftImportMappingRepository(database);
    final created = DateTime(2026, 1, 1);

    await repository.upsert(
      ImportEntityMapping(
        id: 'mapping-1',
        source: ImportSource.yimu,
        entityKind: ImportEntityKind.account,
        sourceEntityKey: 'asset:a',
        targetAccountId: 'target-a',
        createdAt: created,
        updatedAt: created,
      ),
    );
    await repository.upsert(
      ImportEntityMapping(
        id: 'mapping-2',
        source: ImportSource.yimu,
        entityKind: ImportEntityKind.account,
        sourceEntityKey: 'asset:a',
        targetAccountId: 'target-b',
        createdAt: created.add(const Duration(days: 1)),
        updatedAt: created.add(const Duration(days: 1)),
      ),
    );

    final mapping = await repository.find(
      source: ImportSource.yimu,
      entityKind: ImportEntityKind.account,
      sourceEntityKey: 'asset:a',
    );
    expect(mapping?.id, 'mapping-1');
    expect(mapping?.targetAccountId, 'target-b');
    expect((await repository.findBySource(ImportSource.yimu)), hasLength(1));
  });

  test(
    'duplicate lookup ignores reverted batches and missing top-level rows',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftImportBatchRepository(database);
      final importedAt = DateTime(2026, 1, 1);

      await database.customStatement('''
      INSERT INTO transactions
        (id, business_purpose, occurred_at, posted_at, primary_amount_minor, source_kind)
      VALUES ('tx-live', 'dailyExpense', 100, 100, 100, 'import')
    ''');
      await repository.saveImportedBatch(
        batch: ImportBatch(
          id: 'batch-live',
          source: ImportSource.yimu,
          status: ImportBatchStatus.imported,
          importedGroupCount: 1,
          createdTransactionCount: 1,
          skippedGroupCount: 0,
          importedAt: importedAt,
        ),
        items: const [
          ImportBatchItem(
            id: 'item-live',
            batchId: 'batch-live',
            sourceOperationKey: 'operation-1',
            sourceOperationFingerprint: 'fingerprint-1',
            fingerprintVersion: 1,
            topLevelTransactionId: 'tx-live',
          ),
        ],
      );

      await repository.saveImportedBatch(
        batch: ImportBatch(
          id: 'batch-reverted',
          source: ImportSource.yimu,
          status: ImportBatchStatus.imported,
          importedGroupCount: 1,
          createdTransactionCount: 1,
          skippedGroupCount: 0,
          importedAt: importedAt.add(const Duration(minutes: 1)),
        ),
        items: const [
          ImportBatchItem(
            id: 'item-reverted',
            batchId: 'batch-reverted',
            sourceOperationKey: 'operation-1',
            sourceOperationFingerprint: 'fingerprint-1',
            fingerprintVersion: 1,
            topLevelTransactionId: 'tx-live',
          ),
        ],
      );
      await repository.markReverted(
        batchId: 'batch-reverted',
        revertedAt: importedAt.add(const Duration(minutes: 2)),
      );

      await repository.saveImportedBatch(
        batch: ImportBatch(
          id: 'batch-missing',
          source: ImportSource.yimu,
          status: ImportBatchStatus.imported,
          importedGroupCount: 1,
          createdTransactionCount: 1,
          skippedGroupCount: 0,
          importedAt: importedAt.add(const Duration(minutes: 3)),
        ),
        items: const [
          ImportBatchItem(
            id: 'item-missing',
            batchId: 'batch-missing',
            sourceOperationKey: 'operation-1',
            sourceOperationFingerprint: 'fingerprint-1',
            fingerprintVersion: 1,
            topLevelTransactionId: 'tx-missing',
          ),
        ],
      );

      final match = await repository.findDuplicates(
        source: ImportSource.yimu,
        sourceOperationKey: 'operation-1',
        sourceOperationFingerprint: 'fingerprint-1',
        fingerprintVersion: 1,
      );
      expect(match.exactItem?.id, 'item-live');
      expect(match.fingerprintItems.map((item) => item.id), ['item-live']);
    },
  );
}
