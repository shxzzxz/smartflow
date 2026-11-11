import 'package:drift/drift.dart';
import 'package:logging/logging.dart';

import '../../../core/persistence/persistence_baseline.dart';
import '../app_database.dart';
import '../builtin_data.dart';
import 'current_schema.dart';
import 'schema_versions.dart';

final _logger = Logger('infra.database');

/// Database schema compatibility starts at v60; the current version is
/// defined by `AppDatabase.schemaVersion`.
///
/// Databases predating the supported baseline are intentionally unsupported.
/// Schema changes must add immutable one-step migrations backed by Drift
/// snapshots.
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
  if (from < PersistenceBaseline.databaseSchemaVersion || to > currentVersion) {
    _logger.severe(
      'Rejected unsupported database schema upgrade: v$from -> v$to.',
    );
    throw UnsupportedError(
      'Database schema v$from is no longer supported. '
      'This build supports '
      'v${PersistenceBaseline.databaseSchemaVersion} through v$currentVersion.',
    );
  }

  await migrator.database.transaction(() async {
    await stepByStep(
      from60To61: (migration, schema) async {
        await migration.alterTable(
          TableMigration(
            schema.commercialInsurances,
            newColumns: [schema.commercialInsurances.premiumTermCount],
            columnTransformer: {
              schema.commercialInsurances.premiumTermCount: const Constant(
                null,
              ),
            },
          ),
        );
        await migration.database.customStatement(
          "UPDATE commercial_insurances "
          "SET premium_frequency = 'other' "
          "WHERE premium_frequency IN ('quarterly', 'semiAnnual')",
        );
        await migration.database.customStatement(
          "UPDATE coverage_responsibilities "
          "SET kind = 'other' "
          "WHERE kind = 'custom'",
        );

        await migration.createTable(schema.socialInsurances);
        await migration.createTable(schema.socialContributionRecords);
        await migration.database.customStatement(
          'INSERT INTO social_insurances '
          '(id, insured_person_id, region, insurance_type, participant_type, '
          'created_at, updated_at) '
          "SELECT id, insured_person_id, region, 'medical', participant_type, "
          'created_at, updated_at '
          'FROM social_medical_insurances',
        );
        await migration.database.customStatement(
          'INSERT INTO social_insurances '
          '(id, insured_person_id, region, insurance_type, participant_type, '
          'created_at, updated_at) '
          "SELECT id, insured_person_id, region, 'pension', participant_type, "
          'created_at, updated_at '
          'FROM social_pension_insurances',
        );
        await migration.database.customStatement(
          'INSERT INTO social_contribution_records '
          '(social_insurance_id, year_month, contribution_base_minor) '
          'SELECT social_medical_insurance_id, year_month, '
          'contribution_base_minor '
          'FROM social_medical_contribution_records',
        );
        await migration.database.customStatement(
          'INSERT INTO social_contribution_records '
          '(social_insurance_id, year_month, contribution_base_minor) '
          'SELECT social_pension_insurance_id, year_month, '
          'contribution_base_minor '
          'FROM social_pension_contribution_records',
        );
        await migration.database.customStatement(
          'CREATE INDEX social_insurances_person_idx '
          'ON social_insurances (insured_person_id)',
        );
        await migration.database.customStatement(
          'DROP TABLE social_medical_contribution_records',
        );
        await migration.database.customStatement(
          'DROP TABLE social_pension_contribution_records',
        );
        await migration.database.customStatement(
          'DROP TABLE social_medical_insurances',
        );
        await migration.database.customStatement(
          'DROP TABLE social_pension_insurances',
        );
      },
      from61To62: (migration, schema) async {
        await migration.createTable(schema.accountReconciliationSnapshots);
      },
    )(migrator, from, to);
  });
}
