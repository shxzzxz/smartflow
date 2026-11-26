import 'package:smartflow/application/data_management/backup/backup_models.dart';
import 'package:smartflow/domain/ledger/entity/book.dart';

/// A current-contract snapshot for tests focused on other business fields.
BackupSnapshot createBackupSnapshot({
  Map<String, Iterable<BackupJson>> tables = const {},
  Map<String, Object?> preferences = const {},
}) => BackupSnapshot(
  tables: {
    'asset_views': [
      {
        'id': 'builtin-asset-view-all',
        'name': '默认',
        'accountIdsJson': '[]',
        'groupsJson': '[]',
        'accountGroupIdsJson': '{}',
        'sortOrder': 0,
        'version': 0,
        'createdAt': 0,
        'updatedAt': 0,
      },
    ],
    'books': [
      {
        'id': Book.dailyId,
        'name': Book.dailyName,
        'sortOrder': 0,
        'createdAt': 0,
        'updatedAt': 0,
      },
    ],
    ...tables,
    if (tables.containsKey('transactions'))
      'transactions': [
        for (final row in tables['transactions']!)
          {'bookId': Book.dailyId, ...row},
      ],
  },
  preferences: preferences,
);
