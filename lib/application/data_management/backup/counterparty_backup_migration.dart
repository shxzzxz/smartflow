import 'backup_models.dart';

/// Converts pre-v47 backups from an embedded counterparty name to a stable
/// vocabulary row plus `counterpartyId` reference.
void migrateCounterpartyBackup(Map<String, Iterable<BackupJson>> tables) {
  final counterpartyRows = <BackupJson>[
    for (final row in tables['counterparties'] ?? const <BackupJson>[])
      {...row},
  ];
  final idByName = <String, String>{
    for (final row in counterpartyRows)
      if (row['name'] case final String name) name: '${row['id']}',
  };
  var nextLegacyIndex = 1;

  String idForName(String name) {
    final existing = idByName[name];
    if (existing != null) return existing;
    String id;
    do {
      id = 'counterparty:legacy:${nextLegacyIndex++}';
    } while (counterpartyRows.any((row) => row['id'] == id));
    idByName[name] = id;
    counterpartyRows.add({
      'id': id,
      'name': name,
      'createdAt': 0,
      'updatedAt': 0,
    });
    return id;
  }

  var changed =
      counterpartyRows.length != (tables['counterparties']?.length ?? 0);
  final transactions = <BackupJson>[];
  for (final source in tables['transactions'] ?? const <BackupJson>[]) {
    final row = {...source};
    final legacyName = row.remove('counterpartyName');
    if (legacyName is String && legacyName.trim().isNotEmpty) {
      row['counterpartyId'] = idForName(legacyName.trim());
      changed = true;
    } else if (legacyName != null) {
      row['counterpartyId'] = null;
      changed = true;
    }
    transactions.add(row);
  }

  if (changed) {
    tables['counterparties'] = counterpartyRows;
    tables['transactions'] = transactions;
  }
}
