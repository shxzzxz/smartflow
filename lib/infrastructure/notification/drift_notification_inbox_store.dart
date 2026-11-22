import 'dart:convert';

import 'package:drift/drift.dart';

import '../../application/shared/notification/notification_inbox_store.dart';
import '../../application/shared/notification/notification_message.dart';
import '../database/app_database.dart';

/// Notification history is local operational data, separate from settings.
class DriftNotificationInboxStore implements NotificationInboxStore {
  const DriftNotificationInboxStore(this._database);

  static const _key = 'notification.inbox';
  final AppDatabase _database;

  Selectable<AppMetadataRow> _query() =>
      _database.select(_database.appMetadata)
        ..where((table) => table.key.equals(_key));

  @override
  Future<List<NotificationMessage>> read() async =>
      _decode((await _query().getSingleOrNull())?.value);

  @override
  Stream<List<NotificationMessage>> watch() =>
      _query().watchSingleOrNull().map((row) => _decode(row?.value));

  @override
  Future<void> save(List<NotificationMessage> messages) => _database
      .into(_database.appMetadata)
      .insertOnConflictUpdate(
        AppMetadataCompanion.insert(
          key: _key,
          value: jsonEncode({
            'messages': [for (final message in messages) message.toJson()],
          }),
          updatedAt: Value(DateTime.now()),
        ),
      )
      .then((_) {});

  List<NotificationMessage> _decode(String? value) {
    if (value == null) return const [];
    try {
      final json = jsonDecode(value);
      if (json is! Map<String, dynamic> || json['messages'] is! List) {
        return const [];
      }
      final messages = <String, NotificationMessage>{};
      for (final entry in json['messages'] as List) {
        if (entry is! Map<String, dynamic>) continue;
        try {
          final message = NotificationMessage.fromJson(entry);
          messages[message.identity] = message;
        } on FormatException {
          // Keep valid history when an unrelated record is malformed.
        }
      }
      return messages.values.toList();
    } on FormatException {
      return const [];
    }
  }
}
