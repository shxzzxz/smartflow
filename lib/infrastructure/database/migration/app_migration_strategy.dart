import 'package:drift/drift.dart';
import 'package:logging/logging.dart';

import '../app_database.dart';
import '../builtin_data.dart';
import 'current_schema.dart';
import 'schema_versions.dart';

final _logger = Logger('infra.database');

/// Schema v49 is the first supported database contract and v50 is current.
///
/// Pre-release databases are intentionally unsupported. Future versions must
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
  )(migrator, from, to);
}
