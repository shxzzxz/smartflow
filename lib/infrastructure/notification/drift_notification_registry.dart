import 'dart:convert';

import 'package:drift/drift.dart';

import '../../application/shared/notification/notification_registry.dart';
import '../database/app_database.dart';

class DriftNotificationRegistry implements NotificationRegistry {
  const DriftNotificationRegistry(this._database);

  // Operational state is deliberately excluded from settings-only backups.
  static const _key = 'notification.registrations';
  final AppDatabase _database;

  @override
  Future<NotificationRegistryState> read() async {
    final row = await (_database.select(
      _database.appMetadata,
    )..where((table) => table.key.equals(_key))).getSingleOrNull();
    if (row == null) return NotificationRegistryState();
    try {
      final json = jsonDecode(row.value);
      if (json is! Map<String, dynamic> || json['entries'] is! List) {
        return NotificationRegistryState();
      }
      final entries = <RegisteredNotification>[];
      for (final value in json['entries'] as List) {
        if (value is! Map<String, dynamic>) continue;
        try {
          entries.add(RegisteredNotification.fromJson(value));
        } on FormatException {
          // A malformed operational record does not block the remaining plans.
        }
      }
      return NotificationRegistryState(
        entries: entries,
        permissionRequested: json['permissionRequested'] == true,
      );
    } on FormatException {
      return NotificationRegistryState();
    }
  }

  @override
  Future<void> save(NotificationRegistryState state) => _database
      .into(_database.appMetadata)
      .insertOnConflictUpdate(
        AppMetadataCompanion.insert(
          key: _key,
          value: jsonEncode({
            'entries': [for (final entry in state.entries) entry.toJson()],
            'permissionRequested': state.permissionRequested,
          }),
          updatedAt: Value(DateTime.now()),
        ),
      )
      .then((_) {});
}
