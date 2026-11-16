import 'dart:convert';
import 'package:drift/drift.dart';

import '../../../core/error/app_exception.dart';
import '../../../domain/intake/rules/port/recognition_rule_repository.dart';
import '../../../domain/intake/rules/recognition_rule.dart';
import '../../../domain/intake/rules/recognition_rule_configuration.dart';
import '../../../domain/intake/rules/recognition_rule_error_code.dart';
import '../../database/app_database.dart';

class DriftRecognitionRuleRepository implements RecognitionRuleRepository {
  const DriftRecognitionRuleRepository(this._database);

  static const storageKey = 'settings.recognition_rules';
  final AppDatabase _database;

  @override
  Future<RecognitionRuleConfiguration> loadConfiguration() async {
    final row = await (_database.select(
      _database.appMetadata,
    )..where((table) => table.key.equals(storageKey))).getSingleOrNull();
    if (row == null) return const RecognitionRuleConfiguration();
    try {
      final json = jsonDecode(row.value);
      if (json is! Map<String, dynamic> ||
          !const [1, 2, 3].contains(json['version']) ||
          json['rules'] is! List) {
        throw const FormatException();
      }
      final rules = [
        for (final raw in json['rules'] as List)
          RecognitionRule.fromJson(_storedRuleMap(raw)),
      ];
      if (rules.map((rule) => rule.id).toSet().length != rules.length) {
        throw const FormatException();
      }
      List<String>? order;
      if (json['version'] != 1) {
        final raw = json['order'];
        if (raw is! List || raw.any((id) => id is! String || id.isEmpty)) {
          throw const FormatException();
        }
        order = raw.cast<String>();
        if (order.toSet().length != order.length) throw const FormatException();
      }
      final bindings = <String, String?>{};
      final deleted = <String>{};
      if (json['version'] == 3) {
        final rawBindings = json['targetBindings'];
        final rawDeleted = json['deletedRuleIds'];
        if (rawBindings is! Map<String, dynamic> || rawDeleted is! List) {
          throw const FormatException();
        }
        for (final entry in rawBindings.entries) {
          if (entry.key.isEmpty ||
              (entry.value != null &&
                  (entry.value is! String ||
                      (entry.value as String).isEmpty))) {
            throw const FormatException();
          }
          bindings[entry.key] = entry.value as String?;
        }
        for (final id in rawDeleted) {
          if (id is! String || id.isEmpty || !deleted.add(id)) {
            throw const FormatException();
          }
        }
      }
      return RecognitionRuleConfiguration(
        overrides: List.unmodifiable(rules),
        order: order == null ? null : List.unmodifiable(order),
        targetBindings: Map.unmodifiable(bindings),
        deletedRuleIds: Set.unmodifiable(deleted),
      );
    } on FormatException {
      throw InfrastructureException(
        RecognitionRuleErrorCode.configurationUnavailable,
      );
    }
  }

  @override
  Future<void> saveConfiguration(
    RecognitionRuleConfiguration configuration,
  ) async {
    await _database
        .into(_database.appMetadata)
        .insertOnConflictUpdate(
          AppMetadataCompanion.insert(
            key: storageKey,
            value: jsonEncode({
              'version': 3,
              'rules': [
                for (final rule in configuration.overrides) rule.toJson(),
              ],
              'order': configuration.order ?? const <String>[],
              'targetBindings': configuration.targetBindings,
              'deletedRuleIds': configuration.deletedRuleIds.toList(),
            }),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }
}

Map<String, Object?> _storedRuleMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  throw const FormatException();
}
