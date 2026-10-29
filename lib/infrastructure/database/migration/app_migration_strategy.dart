import 'package:drift/drift.dart';
import 'package:logging/logging.dart';

import '../app_database.dart';
import '../builtin_data.dart';
import 'current_schema.dart';
import 'schema_versions.dart';

final _logger = Logger('infra.database');

/// Database schema compatibility starts at v49; the current version is
/// defined by `AppDatabase.schemaVersion`.
///
/// Pre-release databases are intentionally unsupported. Schema changes must
/// add immutable one-step migrations backed by Drift schema snapshots.
MigrationStrategy buildMigrationStrategy(AppDatabase database) {
  return MigrationStrategy(
    onCreate: (migrator) async {
      _logger.info('Creating database schema at v${database.schemaVersion}.');
      await createCurrentSchema(database, migrator);
    },
    beforeOpen: (details) async {
      if (details.hadUpgrade) {
        _logger.info(
          'Database opened after upgrade: '
          'v${details.versionBefore} -> v${details.versionNow}.',
        );
      } else {
        _logger.fine('Database opened at v${details.versionNow}.');
      }
      await ensureBuiltinData(database);
    },
    onUpgrade: (migrator, from, to) =>
        _upgrade(migrator, from, to, currentVersion: database.schemaVersion),
  );
}

Future<void> _upgrade(
  Migrator migrator,
  int from,
  int to, {
  required int currentVersion,
}) async {
  if (from < 49 || to > currentVersion) {
    _logger.severe(
      'Rejected unsupported database schema upgrade: v$from -> v$to.',
    );
    throw UnsupportedError(
      'Database schema v$from is no longer supported. '
      'This build supports v49 through v$currentVersion.',
    );
  }

  await stepByStep(
    from49To50: (migration, schema) async {
      await migration.alterTable(TableMigration(schema.accounts));
    },
    from50To51: (migration, schema) async {
      await migration.alterTable(
        TableMigration(
          schema.installmentContracts,
          newColumns: [schema.installmentContracts.purchaseTransactionId],
          columnTransformer: {
            schema.installmentContracts.purchaseTransactionId: const Constant(
              null,
            ),
          },
        ),
      );
      await migration.createTable(schema.installmentRefundReductions);
      await migration.database.customStatement(
        'CREATE INDEX installment_refund_reductions_contract_idx '
        'ON installment_refund_reductions (contract_id)',
      );
    },
  )(migrator, from, to);
}
