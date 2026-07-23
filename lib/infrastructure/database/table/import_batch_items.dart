import 'package:drift/drift.dart';

@DataClassName('ImportBatchItemRow')
class ImportBatchItems extends Table {
  TextColumn get id => text()();

  TextColumn get batchId => text().named('batch_id')();

  TextColumn get sourceOperationKey =>
      text().named('source_operation_key').nullable()();

  TextColumn get sourceOperationFingerprint =>
      text().named('source_operation_fingerprint')();

  IntColumn get fingerprintVersion => integer().named('fingerprint_version')();

  TextColumn get topLevelTransactionId =>
      text().named('top_level_transaction_id')();

  @override
  Set<Column> get primaryKey => {id};
}
