import 'package:drift/drift.dart';

import '../../../domain/import/import_models.dart';

/// Cross-batch default mappings for one import source.
///
/// The target is intentionally an account id rather than a foreign key. Import
/// mappings belong to the import context and must not make the ledger schema
/// depend on that context.
@DataClassName('ImportEntityMappingRow')
class ImportEntityMappings extends Table {
  TextColumn get id => text()();

  TextColumn get source => textEnum<ImportSource>()();

  TextColumn get entityKind =>
      textEnum<ImportEntityKind>().named('entity_kind')();

  TextColumn get sourceEntityKey =>
      text().named('source_entity_key').withLength(min: 1, max: 500)();

  TextColumn get targetAccountId =>
      text().named('target_account_id').withLength(min: 1, max: 120)();

  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
