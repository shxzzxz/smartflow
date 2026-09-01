import 'dart:convert';
import 'dart:typed_data';

/// The logical tables included in a SmartFlow backup.
class BackupTables {
  BackupTables._();

  static const all = <String>[
    'accounts',
    'account_groups',
    'transactions',
    'transaction_lines',
    'entries',
    'tags',
    'transaction_tags',
    'budgets',
    'credit_liability_accounts',
    'bills',
    'bill_items',
    'bill_generation_suppressions',
    'installment_contracts',
    'installment_schedules',
    'repayments',
    'repayment_items',
    'import_entity_mappings',
    'import_batches',
    'import_batch_items',
  ];

  static String sectionFor(String table) {
    if (const {
      'accounts',
      'account_groups',
      'transactions',
      'transaction_lines',
      'entries',
      'tags',
      'transaction_tags',
      'budgets',
    }.contains(table)) {
      return 'ledger';
    }
    if (const {
      'credit_liability_accounts',
      'bills',
      'bill_items',
      'bill_generation_suppressions',
      'installment_contracts',
      'installment_schedules',
      'repayments',
      'repayment_items',
    }.contains(table)) {
      return 'credit';
    }
    if (const {
      'import_entity_mappings',
      'import_batches',
      'import_batch_items',
    }.contains(table)) {
      return 'import';
    }
    throw ArgumentError('Unknown backup table: $table');
  }
}

typedef BackupJson = Map<String, Object?>;

/// Serialized backup package passed between the application use case and the
/// platform-specific storage adapter. The application layer never needs to
/// know whether it is backed by a directory, ZIP archive, or another store.
class BackupPackage {
  BackupPackage({required this.manifest, required Map<String, Uint8List> files})
    : files = {
        for (final entry in files.entries)
          entry.key: Uint8List.fromList(entry.value),
      };

  final BackupManifest manifest;
  final Map<String, Uint8List> files;
}

abstract interface class BackupPackageStore {
  Future<void> write(Object destination, BackupPackage package);

  Future<BackupPackage> read(Object source);
}

class BackupSnapshot {
  BackupSnapshot({
    Map<String, Iterable<BackupJson>> tables = const {},
    Map<String, Object?> preferences = const {},
  }) : tables = {
         for (final table in BackupTables.all)
           table: List.unmodifiable(tables[table] ?? const <BackupJson>[]),
       },
       preferences = Map.unmodifiable(preferences);

  final Map<String, List<BackupJson>> tables;
  final Map<String, Object?> preferences;

  List<BackupJson> rows(String table) => tables[table] ?? const [];

  BackupSnapshot copyWith({
    Map<String, Iterable<BackupJson>>? tables,
    Map<String, Object?>? preferences,
  }) {
    return BackupSnapshot(
      tables: tables ?? this.tables,
      preferences: preferences ?? this.preferences,
    );
  }
}

class BackupFileDescriptor {
  const BackupFileDescriptor({
    required this.path,
    required this.table,
    required this.rowCount,
    required this.byteCount,
    required this.sha256,
  });

  final String path;
  final String table;
  final int rowCount;
  final int byteCount;
  final String sha256;

  BackupJson toJson() => {
    'path': path,
    'table': table,
    'rowCount': rowCount,
    'byteCount': byteCount,
    'sha256': sha256,
  };

  factory BackupFileDescriptor.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid backup file entry.');
    }
    final map = _stringMap(value, 'Invalid backup file entry.');
    final path = _requiredString(map, 'path');
    final table = _requiredString(map, 'table');
    if (table != 'preferences' && !BackupTables.all.contains(table) ||
        path.contains('..') ||
        path.contains('\u0000') ||
        path.startsWith('/') ||
        path.startsWith('\\') ||
        RegExp(r'^[A-Za-z]:').hasMatch(path)) {
      throw const FormatException('Invalid backup file path or table.');
    }
    final rowCount = _requiredInt(map, 'rowCount');
    final byteCount = _requiredInt(map, 'byteCount');
    final sha256 = _requiredString(map, 'sha256').toLowerCase();
    if (rowCount < 0 ||
        byteCount < 0 ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)) {
      throw const FormatException('Invalid backup file metadata.');
    }
    return BackupFileDescriptor(
      path: path,
      table: table,
      rowCount: rowCount,
      byteCount: byteCount,
      sha256: sha256,
    );
  }
}

class BackupManifest {
  const BackupManifest({
    required this.formatVersion,
    required this.appVersion,
    required this.schemaVersion,
    required this.createdAt,
    required this.baseCurrency,
    required this.minorUnit,
    required this.backupId,
    required this.files,
    this.encryption,
  });

  static const currentFormatVersion = 1;

  final int formatVersion;
  final String appVersion;
  final int schemaVersion;
  final DateTime createdAt;
  final String baseCurrency;
  final int minorUnit;
  final String backupId;
  final List<BackupFileDescriptor> files;
  final Map<String, Object?>? encryption;

  BackupJson toJson() => {
    'formatVersion': formatVersion,
    'appVersion': appVersion,
    'schemaVersion': schemaVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'baseCurrency': baseCurrency,
    'minorUnit': minorUnit,
    'backupId': backupId,
    'requiredFiles': files.map((file) => file.toJson()).toList(),
    if (encryption != null) 'encryption': encryption,
  };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory BackupManifest.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Backup manifest must be an object.');
    }
    final map = _stringMap(value, 'Backup manifest must be an object.');
    final filesValue = map['requiredFiles'];
    if (filesValue is! List) {
      throw const FormatException('Backup manifest is missing requiredFiles.');
    }
    final formatVersion = _requiredInt(map, 'formatVersion');
    if (formatVersion < 1 || formatVersion > currentFormatVersion) {
      throw FormatException(
        'Backup format $formatVersion is not supported; current format is $currentFormatVersion.',
      );
    }
    final createdAt = DateTime.tryParse(_requiredString(map, 'createdAt'));
    if (createdAt == null) {
      throw const FormatException('Invalid backup creation time.');
    }
    final baseCurrency = _requiredString(map, 'baseCurrency').toUpperCase();
    final minorUnit = _requiredInt(map, 'minorUnit');
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(baseCurrency) ||
        minorUnit < 0 ||
        minorUnit > 8) {
      throw const FormatException('Invalid backup currency metadata.');
    }
    final encryptionValue = map['encryption'];
    if (encryptionValue != null && encryptionValue is! Map) {
      throw const FormatException('Invalid backup encryption metadata.');
    }
    final files = filesValue
        .map(BackupFileDescriptor.fromJson)
        .toList(growable: false);
    if (files.map((file) => file.path).toSet().length != files.length) {
      throw const FormatException('Backup manifest contains duplicate files.');
    }
    return BackupManifest(
      formatVersion: formatVersion,
      appVersion: _requiredString(map, 'appVersion'),
      schemaVersion: _requiredInt(map, 'schemaVersion'),
      createdAt: createdAt,
      baseCurrency: baseCurrency,
      minorUnit: minorUnit,
      backupId: _requiredString(map, 'backupId'),
      files: files,
      encryption: (encryptionValue as Map?)?.cast<String, Object?>(),
    );
  }
}

class BackupDiffItem {
  const BackupDiffItem({
    required this.table,
    required this.added,
    required this.removed,
    required this.changed,
  });

  final String table;
  final int added;
  final int removed;
  final int changed;

  int get total => added + removed + changed;
}

class BackupBusinessDiffItem {
  const BackupBusinessDiffItem({
    required this.businessArea,
    required this.added,
    required this.removed,
    required this.changed,
  });

  final String businessArea;
  final int added;
  final int removed;
  final int changed;

  int get total => added + removed + changed;
}

class BackupDiff {
  const BackupDiff(this.items);

  final List<BackupDiffItem> items;

  bool get isNoop => items.every((item) => item.total == 0);

  int get addedCount => items.fold(0, (sum, item) => sum + item.added);
  int get removedCount => items.fold(0, (sum, item) => sum + item.removed);
  int get changedCount => items.fold(0, (sum, item) => sum + item.changed);

  List<BackupBusinessDiffItem> get businessItems {
    final grouped = <String, List<int>>{};
    String area(String table) {
      if (table == 'accounts' || table == 'account_groups') return '账户';
      if (table == 'transactions' ||
          table == 'transaction_lines' ||
          table == 'entries' ||
          table == 'transaction_tags') {
        return '交易组';
      }
      if (table == 'budgets') return '预算';
      if (table == 'import_batches' ||
          table == 'import_batch_items' ||
          table == 'import_entity_mappings') {
        return '导入批次';
      }
      if (table == 'bills' || table == 'bill_items') return '账单';
      if (table == 'installment_contracts' ||
          table == 'installment_schedules' ||
          table == 'repayments' ||
          table == 'repayment_items' ||
          table == 'credit_liability_accounts' ||
          table == 'bill_generation_suppressions') {
        return '信贷合同';
      }
      return table;
    }

    for (final item in items) {
      final values = grouped.putIfAbsent(area(item.table), () => [0, 0, 0]);
      values[0] += item.added;
      values[1] += item.removed;
      values[2] += item.changed;
    }
    return [
      for (final entry in grouped.entries)
        BackupBusinessDiffItem(
          businessArea: entry.key,
          added: entry.value[0],
          removed: entry.value[1],
          changed: entry.value[2],
        ),
    ];
  }

  BackupDiffItem itemFor(String table) => items.firstWhere(
    (item) => item.table == table,
    orElse: () =>
        BackupDiffItem(table: table, added: 0, removed: 0, changed: 0),
  );

  String get summary => isNoop
      ? '数据完全一致，无需恢复。'
      : businessItems
            .where((item) => item.total > 0)
            .map(
              (item) =>
                  '${item.businessArea}新增 ${item.added} 项、删除 ${item.removed} 项、修改 ${item.changed} 项',
            )
            .join('；');

  static BackupDiff compare(BackupSnapshot current, BackupSnapshot incoming) {
    final result = <BackupDiffItem>[];
    for (final table in BackupTables.all) {
      final currentById = _indexRows(current.rows(table), table);
      final incomingById = _indexRows(incoming.rows(table), table);
      var added = 0;
      var removed = 0;
      var changed = 0;
      for (final id in incomingById.keys) {
        if (!currentById.containsKey(id)) {
          added++;
        } else if (_canonical(currentById[id]!) !=
            _canonical(incomingById[id]!)) {
          changed++;
        }
      }
      for (final id in currentById.keys) {
        if (!incomingById.containsKey(id)) removed++;
      }
      result.add(
        BackupDiffItem(
          table: table,
          added: added,
          removed: removed,
          changed: changed,
        ),
      );
    }
    final currentPreferences = current.preferences;
    final incomingPreferences = incoming.preferences;
    final currentKeys = currentPreferences.keys.toSet();
    final incomingKeys = incomingPreferences.keys.toSet();
    final addedPreferences = incomingKeys.difference(currentKeys).length;
    final removedPreferences = currentKeys.difference(incomingKeys).length;
    final changedPreferences = incomingKeys
        .intersection(currentKeys)
        .where(
          (key) =>
              _canonical(currentPreferences[key]) !=
              _canonical(incomingPreferences[key]),
        )
        .length;
    if (addedPreferences + removedPreferences + changedPreferences > 0) {
      result.add(
        BackupDiffItem(
          table: 'preferences',
          added: addedPreferences,
          removed: removedPreferences,
          changed: changedPreferences,
        ),
      );
    }
    return BackupDiff(List.unmodifiable(result));
  }
}

class BackupValidationException implements Exception {
  const BackupValidationException(this.message);

  final String message;

  @override
  String toString() => 'BackupValidationException: $message';
}

class BackupValidationReport {
  const BackupValidationReport({required this.errors});

  final List<String> errors;

  bool get isValid => errors.isEmpty;
}

String _requiredString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Backup field "$key" must be a non-empty string.');
  }
  return value;
}

Map<String, Object?> _stringMap(Map value, String message) {
  if (value.keys.any((key) => key is! String)) {
    throw FormatException(message);
  }
  return {for (final entry in value.entries) entry.key as String: entry.value};
}

int _requiredInt(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is int) return value;
  if (value is num && value == value.roundToDouble()) return value.toInt();
  throw FormatException('Backup field "$key" must be an integer.');
}

Map<String, BackupJson> _indexRows(Iterable<BackupJson> rows, String table) {
  final result = <String, BackupJson>{};
  for (final row in rows) {
    final id = _rowIdentity(row, table);
    if (result.containsKey(id)) {
      throw BackupValidationException('Duplicate identity "$id" in $table.');
    }
    result[id] = row;
  }
  return result;
}

String _rowIdentity(BackupJson row, String table) {
  if (table == 'preferences') return '${row['key']}';
  if (table == 'transaction_tags') {
    return '${row['transactionId']}\u0000${row['tagId']}';
  }
  if (table == 'bill_generation_suppressions') {
    return '${row['accountId']}\u0000${row['period']}';
  }
  return '${row['id']}';
}

String _canonical(Object? value) {
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    return '{${entries.map((entry) => '${jsonEncode(entry.key.toString())}:${_canonical(entry.value)}').join(',')}}';
  }
  if (value is Iterable) return '[${value.map(_canonical).join(',')}]';
  return jsonEncode(value);
}
