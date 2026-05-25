import 'package:drift/drift.dart' show Value;

import 'package:smartflow/application/shared/update_channel_store.dart';
import 'package:smartflow/data/app_database.dart';

class DriftUpdateChannelStore implements UpdateChannelStore {
  const DriftUpdateChannelStore(this._database);

  static const _key = 'update.channel';

  final AppDatabase _database;

  @override
  Future<String?> readUpdateChannel() async {
    final row =
        await (_database.select(_database.appMetadata)
          ..where((table) => table.key.equals(_key))).getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> saveUpdateChannel(String code) {
    return _database
        .into(_database.appMetadata)
        .insertOnConflictUpdate(
          AppMetadataCompanion.insert(
            key: _key,
            value: code,
            updatedAt: Value(DateTime.now()),
          ),
        );
  }
}
