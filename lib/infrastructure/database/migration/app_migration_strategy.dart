import 'package:drift/drift.dart';
import 'package:logging/logging.dart';

import '../app_database.dart';
import '../builtin_data.dart';
import 'current_schema.dart';

final _logger = Logger('infra.database');

/// Schema v49 is the first supported database contract.
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
    onUpgrade: (_, from, to) async {
      _logger.severe(
        'Rejected unsupported database schema upgrade: v$from -> v$to.',
      );
      throw UnsupportedError(
        'Database schema v$from is no longer supported. '
        'This build requires the v${database.schemaVersion} baseline.',
      );
    },
  );
}
