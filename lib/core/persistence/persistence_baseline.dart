/// Release compatibility baseline shared by database and backup persistence.
///
/// Baseline changes happen at release boundaries. Update these values together
/// with the persistence contract, schema snapshots and migration tests.
final class PersistenceBaseline {
  PersistenceBaseline._();

  static const appVersion = '0.9.5-dev.1';
  static const databaseSchemaVersion = 60;
  static const backupFormatVersion = 3;
  static const backupSchemaVersion = 9;
}
