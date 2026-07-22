import 'package:drift/drift.dart';

import '../../../domain/import/import_models.dart';
import '../../../domain/import/import_persistence_models.dart';
import '../../../domain/import/port/import_batch_repository.dart';
import '../../database/app_database.dart';

class DriftImportBatchRepository implements ImportBatchRepository {
  const DriftImportBatchRepository(this._database);

  final AppDatabase _database;

  @override
  Future<ImportBatch?> findById(String batchId) async {
    final row =
        await (_database.select(_database.importBatches)
          ..where((batch) => batch.id.equals(batchId))).getSingleOrNull();
    return row == null ? null : _mapBatch(row);
  }

  @override
  Future<List<ImportBatch>> list({ImportSource? source}) async {
    final query = _database.select(_database.importBatches)..orderBy([
      (batch) => OrderingTerm.desc(batch.importedAt),
      (batch) => OrderingTerm.desc(batch.id),
    ]);
    if (source != null) {
      query.where((batch) => batch.source.equals(source.name));
    }
    final rows = await query.get();
    return rows.map(_mapBatch).toList(growable: false);
  }

  @override
  Future<List<ImportBatchItem>> findItems(String batchId) async {
    final rows =
        await (_database.select(_database.importBatchItems)
              ..where((item) => item.batchId.equals(batchId))
              ..orderBy([(item) => OrderingTerm.asc(item.id)]))
            .get();
    return rows.map(_mapItem).toList(growable: false);
  }

  @override
  Future<ImportDuplicateMatch> findDuplicates({
    required ImportSource source,
    required String? sourceOperationKey,
    required String sourceOperationFingerprint,
    required int fingerprintVersion,
  }) async {
    final exactItems =
        sourceOperationKey == null
            ? const <ImportBatchItem>[]
            : await _findMatchingItems(
              source: source,
              operationKey: sourceOperationKey,
            );
    final fingerprintItems = await _findMatchingItems(
      source: source,
      fingerprint: sourceOperationFingerprint,
      fingerprintVersion: fingerprintVersion,
    );
    return ImportDuplicateMatch(
      exactItem: exactItems.isEmpty ? null : exactItems.first,
      fingerprintItems: fingerprintItems,
    );
  }

  @override
  Future<void> saveImportedBatch({
    required ImportBatch batch,
    required Iterable<ImportBatchItem> items,
  }) async {
    await _database
        .into(_database.importBatches)
        .insert(
          ImportBatchesCompanion.insert(
            id: batch.id,
            source: batch.source,
            status: batch.status,
            importedGroupCount: batch.importedGroupCount,
            createdTransactionCount: batch.createdTransactionCount,
            skippedGroupCount: batch.skippedGroupCount,
            importedAt: batch.importedAt,
            revertedAt: Value(batch.revertedAt),
          ),
        );
    final companions = [
      for (final item in items)
        ImportBatchItemsCompanion.insert(
          id: item.id,
          batchId: item.batchId,
          sourceOperationKey: Value(item.sourceOperationKey),
          sourceOperationFingerprint: item.sourceOperationFingerprint,
          fingerprintVersion: item.fingerprintVersion,
          topLevelTransactionId: item.topLevelTransactionId,
        ),
    ];
    if (companions.isNotEmpty) {
      await _database.batch((batchWriter) {
        batchWriter.insertAll(_database.importBatchItems, companions);
      });
    }
  }

  @override
  Future<void> markReverted({
    required String batchId,
    required DateTime revertedAt,
  }) async {
    await (_database.update(_database.importBatches)..where(
      (batch) =>
          batch.id.equals(batchId) &
          batch.status.equals(ImportBatchStatus.imported.name),
    )).write(
      ImportBatchesCompanion(
        status: const Value(ImportBatchStatus.reverted),
        revertedAt: Value(revertedAt),
      ),
    );
  }

  Future<List<ImportBatchItem>> _findMatchingItems({
    required ImportSource source,
    String? operationKey,
    String? fingerprint,
    int? fingerprintVersion,
  }) async {
    final items = _database.importBatchItems;
    final batches = _database.importBatches;
    final transactions = _database.transactions;
    final query = _database.select(items).join([
      innerJoin(batches, batches.id.equalsExp(items.batchId)),
      innerJoin(
        transactions,
        transactions.id.equalsExp(items.topLevelTransactionId),
      ),
    ]);
    Expression<bool> predicate =
        batches.source.equals(source.name) &
        batches.status.equals(ImportBatchStatus.imported.name);
    if (operationKey != null) {
      predicate = predicate & items.sourceOperationKey.equals(operationKey);
    }
    if (fingerprint != null) {
      predicate =
          predicate &
          items.sourceOperationFingerprint.equals(fingerprint) &
          items.fingerprintVersion.equals(fingerprintVersion!);
    }
    query.where(predicate);
    query.orderBy([OrderingTerm.asc(items.id)]);
    final rows = await query.get();
    return rows.map((row) => _mapItem(row.readTable(items))).toList();
  }

  ImportBatch _mapBatch(ImportBatchRow row) {
    return ImportBatch(
      id: row.id,
      source: row.source,
      status: row.status,
      importedGroupCount: row.importedGroupCount,
      createdTransactionCount: row.createdTransactionCount,
      skippedGroupCount: row.skippedGroupCount,
      importedAt: row.importedAt,
      revertedAt: row.revertedAt,
    );
  }

  ImportBatchItem _mapItem(ImportBatchItemRow row) {
    return ImportBatchItem(
      id: row.id,
      batchId: row.batchId,
      sourceOperationKey: row.sourceOperationKey,
      sourceOperationFingerprint: row.sourceOperationFingerprint,
      fingerprintVersion: row.fingerprintVersion,
      topLevelTransactionId: row.topLevelTransactionId,
    );
  }
}
