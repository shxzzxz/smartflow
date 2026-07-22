import 'package:drift/drift.dart';

import '../../../domain/import/import_models.dart';
import '../../../domain/import/import_persistence_models.dart';

@DataClassName('ImportBatchRow')
class ImportBatches extends Table {
  TextColumn get id => text()();

  TextColumn get source => textEnum<ImportSource>()();

  TextColumn get status => textEnum<ImportBatchStatus>()();

  IntColumn get importedGroupCount => integer().named('imported_group_count')();

  IntColumn get createdTransactionCount =>
      integer().named('created_transaction_count')();

  IntColumn get skippedGroupCount => integer().named('skipped_group_count')();

  DateTimeColumn get importedAt => dateTime().named('imported_at')();

  DateTimeColumn get revertedAt => dateTime().named('reverted_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
