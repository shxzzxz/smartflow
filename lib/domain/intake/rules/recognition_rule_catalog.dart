import 'dart:convert';

import '../import/import_models.dart' show ImportCategoryKind;
import 'recognition_rule.dart';
import 'recognition_rule_configuration.dart';
import 'recognition_rule_target.dart';

class RecognitionRuleMatch {
  const RecognitionRuleMatch({
    required this.path,
    required this.ruleId,
    required this.isFallback,
    this.targetAccountId,
  });
  final List<String> path;
  final String ruleId;
  final bool isFallback;
  final String? targetAccountId;
}

/// Shared keyword inference over caller-prepared text; no source field policy.
class RecognitionRuleCatalog {
  RecognitionRuleCatalog({
    required List<RecognitionRule> rules,
    Map<ImportCategoryKind, List<String>> fallbackPaths = const {},
  }) : _defaults = List.unmodifiable(rules),
       rules = _rank(_sortByPriority(rules)),
       fallbackPaths = _paths(fallbackPaths),
       targetBindings = const {},
       deletedRuleIds = const {},
       _targets = null;

  RecognitionRuleCatalog._ordered({
    required List<RecognitionRule> defaults,
    required List<RecognitionRule> rules,
    required this.fallbackPaths,
    required this.targetBindings,
    required this.deletedRuleIds,
    List<RecognitionRuleTarget>? targets,
  }) : _defaults = defaults,
       rules = _rank(rules),
       _targets = targets;

  // Original builtin scores are used only when reading legacy overrides.
  final List<RecognitionRule> _defaults;
  final List<RecognitionRule> rules;
  final Map<ImportCategoryKind, List<String>> fallbackPaths;
  final Map<String, String?> targetBindings;
  final Set<String> deletedRuleIds;
  final List<RecognitionRuleTarget>? _targets;

  static String fallbackRuleId(ImportCategoryKind kind) =>
      '${kind.name}_fallback_other';

  factory RecognitionRuleCatalog.fromJson(Map<String, Object?> json) =>
      RecognitionRuleCatalog(
        rules: [
          for (final raw in json['rules'] as List? ?? const [])
            RecognitionRule.fromJson(
              Map<String, Object?>.from(raw as Map),
            ).copyWith(isBuiltin: true),
          for (final raw in json['keywordRules'] as List? ?? const [])
            _legacyRule(Map<String, Object?>.from(raw as Map)),
          for (final raw in json['directRules'] as List? ?? const [])
            _legacyRule(Map<String, Object?>.from(raw as Map)),
        ],
        fallbackPaths: {
          for (final raw in json['fallbackRules'] as List? ?? const [])
            ImportCategoryKind.values.byName(
              (raw as Map)['direction'] as String,
            ): (raw['categoryPath'] as List)
                .cast<String>(),
        },
      );

  RecognitionRuleCatalog withOverrides(List<RecognitionRule> overrides) =>
      withConfiguration(RecognitionRuleConfiguration(overrides: overrides));

  RecognitionRuleCatalog withConfiguration(
    RecognitionRuleConfiguration configuration,
  ) {
    final byId = {
      for (final rule in _defaults)
        if (!configuration.deletedRuleIds.contains(rule.id)) rule.id: rule,
    };
    for (final override in configuration.overrides) {
      if (configuration.deletedRuleIds.contains(override.id)) continue;
      byId[override.id] = override.copyWith(
        isBuiltin: byId[override.id]?.isBuiltin ?? false,
      );
    }
    for (final entry in byId.entries.toList()) {
      if (entry.value.targetAccountId == null &&
          configuration.targetBindings.containsKey(entry.key)) {
        byId[entry.key] = entry.value.copyWith(
          targetAccountId: configuration.targetBindings[entry.key],
        );
      }
    }
    final order = configuration.order;
    final ordered = order == null
        ? _sortByPriority(byId.values.toList())
        : [
            for (final id in order)
              if (byId.containsKey(id)) byId[id]!,
            for (final rule in _sortByPriority(byId.values.toList()))
              if (!order.contains(rule.id)) rule,
          ];
    return RecognitionRuleCatalog._ordered(
      defaults: _defaults,
      rules: ordered,
      fallbackPaths: fallbackPaths,
      targetBindings: Map.unmodifiable(configuration.targetBindings),
      deletedRuleIds: Set.unmodifiable(configuration.deletedRuleIds),
    );
  }

  /// Keeps unavailable rules visible while matching only this target snapshot.
  RecognitionRuleCatalog withTargets(List<RecognitionRuleTarget> targets) =>
      RecognitionRuleCatalog._ordered(
        defaults: _defaults,
        rules: rules,
        fallbackPaths: fallbackPaths,
        targetBindings: targetBindings,
        deletedRuleIds: deletedRuleIds,
        targets: List.unmodifiable(targets),
      );

  RecognitionRuleConfiguration configurationFor(List<RecognitionRule> ordered) {
    final defaults = {
      for (final rule in _defaults)
        rule.id: rule.copyWith(
          targetAccountId: targetBindings.containsKey(rule.id)
              ? targetBindings[rule.id]
              : rule.targetAccountId,
        ),
    };
    final ranked = _rank(ordered);
    final retainedIds = ranked.map((rule) => rule.id).toSet();
    return RecognitionRuleConfiguration(
      order: List.unmodifiable(ranked.map((rule) => rule.id)),
      targetBindings: targetBindings,
      deletedRuleIds: Set.unmodifiable({
        ...deletedRuleIds,
        for (final rule in [..._defaults, ...rules])
          if (!retainedIds.contains(rule.id)) rule.id,
      }),
      overrides: List.unmodifiable(
        ranked.where((rule) {
          final builtin = defaults[rule.id];
          if (builtin == null) return true;
          final currentJson = rule.toJson()..remove('priority');
          final defaultJson = builtin.toJson()..remove('priority');
          return jsonEncode(currentJson) != jsonEncode(defaultJson);
        }),
      ),
    );
  }

  RecognitionRuleMatch? match({
    required String text,
    RecognitionRuleKind kind = RecognitionRuleKind.category,
    RecognitionRuleSource? source,
    ImportCategoryKind? categoryKind,
  }) {
    final value = text
        .split(RegExp(r'[\r\n]+'))
        .map(normalizeRecognitionText)
        .join('\n');
    for (final rule in rules) {
      if (!rule.enabled || rule.kind != kind) continue;
      if (rule.source != null && rule.source != source) continue;
      if (kind == RecognitionRuleKind.category &&
          categoryKind != null &&
          rule.targetCategoryKind != null &&
          rule.targetCategoryKind != categoryKind) {
        continue;
      }
      final target = _targets
          ?.where(
            (target) =>
                target.id == rule.targetAccountId &&
                target.kind == kind &&
                (kind == RecognitionRuleKind.account ||
                    categoryKind == null ||
                    target.direction == categoryKind),
          )
          .firstOrNull;
      if (_targets != null && target == null) continue;
      if (rule.keywords.any((keyword) {
        final normalized = normalizeRecognitionText(keyword);
        return normalized.isNotEmpty && value.contains(normalized);
      })) {
        return RecognitionRuleMatch(
          // The rule's description keeps inferred source keys stable on rename.
          path: rule.targetPath,
          ruleId: rule.id,
          targetAccountId: rule.targetAccountId,
          isFallback: false,
        );
      }
    }
    final fallback = fallbackPaths[categoryKind];
    if (kind != RecognitionRuleKind.category ||
        fallback == null ||
        categoryKind == null) {
      return null;
    }
    final fallbackId = fallbackRuleId(categoryKind);
    final target = _targets
        ?.where(
          (target) =>
              target.id == targetBindings[fallbackId] &&
              target.kind == RecognitionRuleKind.category &&
              target.direction == categoryKind,
        )
        .firstOrNull;
    if (_targets != null && target == null) return null;
    return RecognitionRuleMatch(
      path: fallback,
      ruleId: fallbackId,
      targetAccountId: target?.id,
      isFallback: true,
    );
  }
}

List<RecognitionRule> _sortByPriority(List<RecognitionRule> rules) {
  final indexed = rules.indexed.toList()
    ..sort((a, b) {
      final score = b.$2.priority.compareTo(a.$2.priority);
      return score == 0 ? a.$1.compareTo(b.$1) : score;
    });
  return indexed.map((entry) => entry.$2).toList();
}

List<RecognitionRule> _rank(List<RecognitionRule> rules) {
  if (rules.map((rule) => rule.id).toSet().length != rules.length) {
    throw const FormatException('Recognition rule IDs must be unique.');
  }
  return List.unmodifiable([
    for (var i = 0; i < rules.length; i++)
      rules[i].copyWith(priority: rules.length - i),
  ]);
}

Map<ImportCategoryKind, List<String>> _paths(
  Map<ImportCategoryKind, List<String>> paths,
) => Map.unmodifiable({
  for (final entry in paths.entries)
    entry.key: List<String>.unmodifiable(entry.value),
});

RecognitionRule _legacyRule(Map<String, Object?> json) {
  final conditions = json['conditions'] as Map?;
  return RecognitionRule.fromJson({
    ...json,
    'kind': 'category',
    'targetPath': json['categoryPath'],
    'keywords':
        json['keywords'] ??
        [
          for (final item in conditions?['items'] as List? ?? const [])
            (item as Map)['value'],
        ],
  }).copyWith(isBuiltin: true);
}
