import '../import/import_models.dart' show ImportCategoryKind;

enum RecognitionRuleKind { account, category }

enum RecognitionRuleSource { wechat, alipay }

class RecognitionRule {
  RecognitionRule({
    required this.id,
    required this.kind,
    required List<String> keywords,
    required this.priority,
    this.source,
    this.targetAccountId,
    List<String> targetPath = const [],
    this.targetCategoryKind,
    this.enabled = true,
    this.isBuiltin = false,
  }) : keywords = List.unmodifiable(keywords),
       targetPath = List.unmodifiable(targetPath);

  final String id;
  final RecognitionRuleKind kind;
  final List<String> keywords;

  /// Unique execution rank, maintained from the catalog's visible order.
  final int priority;
  final RecognitionRuleSource? source;
  final String? targetAccountId;
  final List<String> targetPath;

  /// The target's inherent nature, not a configurable matching condition.
  final ImportCategoryKind? targetCategoryKind;
  final bool enabled;
  final bool isBuiltin;

  String get displayName => keywords.take(3).join('、');

  RecognitionRule copyWith({
    List<String>? keywords,
    int? priority,
    Object? source = _unchanged,
    Object? targetAccountId = _unchanged,
    List<String>? targetPath,
    Object? targetCategoryKind = _unchanged,
    bool? enabled,
    bool? isBuiltin,
  }) => RecognitionRule(
    id: id,
    kind: kind,
    keywords: keywords ?? this.keywords,
    priority: priority ?? this.priority,
    source: identical(source, _unchanged)
        ? this.source
        : source as RecognitionRuleSource?,
    targetAccountId: identical(targetAccountId, _unchanged)
        ? this.targetAccountId
        : targetAccountId as String?,
    targetPath: targetPath ?? this.targetPath,
    targetCategoryKind: identical(targetCategoryKind, _unchanged)
        ? this.targetCategoryKind
        : targetCategoryKind as ImportCategoryKind?,
    enabled: enabled ?? this.enabled,
    isBuiltin: isBuiltin ?? this.isBuiltin,
  );

  factory RecognitionRule.fromJson(Map<String, Object?> json) {
    final priority = json['priority'];
    if (priority is! int) {
      throw const FormatException('Invalid recognition rule.');
    }
    final kind = _ruleEnum(RecognitionRuleKind.values, json['kind']);
    final categoryKind = json['targetCategoryKind'] ?? json['direction'];
    return RecognitionRule(
      id: _ruleString(json['id']),
      kind: kind,
      keywords: _ruleStrings(json['keywords']),
      priority: priority,
      source: json['source'] == null
          ? null
          : _ruleEnum(RecognitionRuleSource.values, json['source']),
      targetAccountId: json['targetAccountId'] == null
          ? null
          : _ruleString(json['targetAccountId']),
      targetPath: _ruleStrings(json['targetPath'], fallback: const []),
      targetCategoryKind:
          kind == RecognitionRuleKind.category && categoryKind != null
          ? _ruleEnum(ImportCategoryKind.values, categoryKind)
          : null,
      enabled: _ruleBool(json['enabled'], true),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'keywords': keywords,
    'priority': priority,
    'source': source?.name,
    'targetAccountId': targetAccountId,
    'targetPath': targetPath,
    'targetCategoryKind': targetCategoryKind?.name,
    'enabled': enabled,
  };
}

const _unchanged = Object();

String normalizeRecognitionText(String? value) {
  final buffer = StringBuffer();
  for (final rune in (value ?? '').runes) {
    buffer.writeCharCode(
      rune == 0x3000
          ? 0x20
          : rune >= 0xFF01 && rune <= 0xFF5E
          ? rune - 0xFEE0
          : rune,
    );
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), '').toLowerCase();
}

String _ruleString(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value;
  throw const FormatException('Invalid recognition rule.');
}

List<String> _ruleStrings(Object? value, {List<String>? fallback}) {
  if (value == null && fallback != null) return fallback;
  if (value is List && value.every((item) => item is String)) {
    return value.cast<String>();
  }
  throw const FormatException('Invalid recognition rule.');
}

T _ruleEnum<T extends Enum>(List<T> values, Object? name) {
  if (name is String) {
    final match = values.where((value) => value.name == name).firstOrNull;
    if (match != null) return match;
  }
  throw const FormatException('Invalid recognition rule.');
}

bool _ruleBool(Object? value, bool fallback) {
  if (value == null) return fallback;
  if (value is bool) return value;
  throw const FormatException('Invalid recognition rule.');
}
