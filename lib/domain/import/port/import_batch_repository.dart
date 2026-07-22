import '../import_models.dart';
import '../import_persistence_models.dart';

abstract interface class ImportBatchRepository {
  Future<ImportBatch?> findById(String batchId);

  Future<List<ImportBatch>> list({ImportSource? source});

  Future<List<ImportBatchItem>> findItems(String batchId);

  Future<ImportDuplicateMatch> findDuplicates({
    required ImportSource source,
    required String? sourceOperationKey,
    required String sourceOperationFingerprint,
    required int fingerprintVersion,
  });

  Future<void> saveImportedBatch({
    required ImportBatch batch,
    required Iterable<ImportBatchItem> items,
  });

  Future<void> markReverted({
    required String batchId,
    required DateTime revertedAt,
  });
}
