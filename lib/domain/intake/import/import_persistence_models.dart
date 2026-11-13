import 'import_models.dart';

enum ImportBatchStatus { imported, reverted }

class ImportEntityMapping {
  const ImportEntityMapping({
    required this.id,
    required this.source,
    required this.entityKind,
    required this.sourceEntityKey,
    required this.targetAccountId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final ImportSource source;
  final ImportEntityKind entityKind;
  final String sourceEntityKey;
  final String targetAccountId;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class ImportBatch {
  const ImportBatch({
    required this.id,
    required this.source,
    required this.status,
    required this.importedGroupCount,
    required this.createdTransactionCount,
    required this.skippedGroupCount,
    required this.importedAt,
    this.revertedAt,
  });

  final String id;
  final ImportSource source;
  final ImportBatchStatus status;
  final int importedGroupCount;
  final int createdTransactionCount;
  final int skippedGroupCount;
  final DateTime importedAt;
  final DateTime? revertedAt;
}

class ImportBatchItem {
  const ImportBatchItem({
    required this.id,
    required this.batchId,
    required this.sourceOperationFingerprint,
    required this.fingerprintVersion,
    required this.topLevelTransactionId,
    this.sourceOperationKey,
  });

  final String id;
  final String batchId;
  final String? sourceOperationKey;
  final String sourceOperationFingerprint;
  final int fingerprintVersion;
  final String topLevelTransactionId;
}

class ImportDuplicateMatch {
  const ImportDuplicateMatch({
    this.exactItem,
    this.fingerprintItems = const [],
  });

  final ImportBatchItem? exactItem;
  final List<ImportBatchItem> fingerprintItems;

  bool get hasExactMatch => exactItem != null;
  bool get hasFingerprintMatch => fingerprintItems.isNotEmpty;
}
