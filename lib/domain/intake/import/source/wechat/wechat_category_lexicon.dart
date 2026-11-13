import '../../import_models.dart';

class WechatCategoryMatch {
  const WechatCategoryMatch({
    required this.path,
    required this.ruleId,
    required this.isFallback,
  });

  final List<String> path;
  final String ruleId;
  final bool isFallback;
}

class WechatCategoryLexicon {
  const WechatCategoryLexicon._({
    required List<_WechatDirectRule> directRules,
    required List<_WechatKeywordRule> keywordRules,
    required List<_WechatFallbackRule> fallbackRules,
  }) : _directRules = directRules,
       _keywordRules = keywordRules,
       _fallbackRules = fallbackRules;

  factory WechatCategoryLexicon.fromJson(Map<String, Object?> json) {
    final directJson = json['directRules'] as List<Object?>? ?? const [];
    final keywordJson = json['keywordRules'] as List<Object?>? ?? const [];
    final fallbackJson = json['fallbackRules'] as List<Object?>? ?? const [];
    return WechatCategoryLexicon._(
      directRules: [
        for (final value in directJson)
          _WechatDirectRule.fromJson(value! as Map<String, Object?>),
      ],
      keywordRules: [
        for (final value in keywordJson)
          _WechatKeywordRule.fromJson(value! as Map<String, Object?>),
      ],
      fallbackRules: [
        for (final value in fallbackJson)
          _WechatFallbackRule.fromJson(value! as Map<String, Object?>),
      ],
    );
  }

  final List<_WechatDirectRule> _directRules;
  final List<_WechatKeywordRule> _keywordRules;
  final List<_WechatFallbackRule> _fallbackRules;

  WechatCategoryMatch? match({
    required ImportCategoryKind direction,
    String? transactionType,
    String? counterparty,
    String? product,
    String? status,
  }) {
    final source = _WechatRuleSource(
      transactionType: transactionType,
      counterparty: counterparty,
      product: product,
      status: status,
    );
    final candidates = <({String id, int priority, List<String> path})>[
      for (final rule in _directRules)
        if (rule.direction == direction && rule.matches(source))
          (id: rule.id, priority: rule.priority, path: rule.categoryPath),
      for (final rule in _keywordRules)
        if (rule.direction == direction && rule.matches(source))
          (id: rule.id, priority: rule.priority, path: rule.categoryPath),
    ];
    if (candidates.isNotEmpty) {
      final priority = candidates
          .map((candidate) => candidate.priority)
          .reduce((left, right) => left > right ? left : right);
      final best = candidates
          .where((candidate) => candidate.priority == priority)
          .toList(growable: false);
      final paths = best.map((candidate) => candidate.path.join(' / ')).toSet();
      if (paths.length == 1) {
        return WechatCategoryMatch(
          path: best.first.path,
          ruleId: best.first.id,
          isFallback: false,
        );
      }
    }
    for (final rule in _fallbackRules) {
      if (rule.direction == direction) {
        return WechatCategoryMatch(
          path: rule.categoryPath,
          ruleId: rule.id,
          isFallback: true,
        );
      }
    }
    return null;
  }
}

class _WechatDirectRule {
  const _WechatDirectRule({
    required this.id,
    required this.direction,
    required this.priority,
    required this.logic,
    required this.conditions,
    required this.categoryPath,
  });

  factory _WechatDirectRule.fromJson(Map<String, Object?> json) {
    final conditionsJson = json['conditions']! as Map<String, Object?>;
    final items = conditionsJson['items']! as List<Object?>;
    return _WechatDirectRule(
      id: json['id']! as String,
      direction: _direction(json['direction']! as String),
      priority: json['priority']! as int,
      logic: conditionsJson['logic']! as String,
      conditions: [
        for (final value in items)
          _WechatCondition.fromJson(value! as Map<String, Object?>),
      ],
      categoryPath: _categoryPath(json),
    );
  }

  final String id;
  final ImportCategoryKind direction;
  final int priority;
  final String logic;
  final List<_WechatCondition> conditions;
  final List<String> categoryPath;

  bool matches(_WechatRuleSource source) {
    final results = [
      for (final condition in conditions) condition.matches(source),
    ];
    return switch (logic) {
      'all' => results.every((value) => value),
      _ => results.any((value) => value),
    };
  }
}

class _WechatKeywordRule {
  const _WechatKeywordRule({
    required this.id,
    required this.direction,
    required this.priority,
    required this.fields,
    required this.keywords,
    required this.categoryPath,
  });

  factory _WechatKeywordRule.fromJson(Map<String, Object?> json) {
    return _WechatKeywordRule(
      id: json['id']! as String,
      direction: _direction(json['direction']! as String),
      priority: json['priority']! as int,
      fields: {
        for (final value in json['fields']! as List<Object?>)
          _field(value! as String),
      },
      keywords: List.unmodifiable(
        (json['keywords']! as List<Object?>).cast<String>().map(_normalize),
      ),
      categoryPath: _categoryPath(json),
    );
  }

  final String id;
  final ImportCategoryKind direction;
  final int priority;
  final Set<_WechatRuleField> fields;
  final List<String> keywords;
  final List<String> categoryPath;

  bool matches(_WechatRuleSource source) {
    for (final field in fields) {
      final value = _normalize(source.valueFor(field));
      if (value.isEmpty) continue;
      if (keywords.any(value.contains)) return true;
    }
    return false;
  }
}

class _WechatCondition {
  const _WechatCondition({
    required this.field,
    required this.operator,
    required this.value,
  });

  factory _WechatCondition.fromJson(Map<String, Object?> json) {
    return _WechatCondition(
      field: _field(json['field']! as String),
      operator: json['operator']! as String,
      value: _normalize(json['value']! as String),
    );
  }

  final _WechatRuleField field;
  final String operator;
  final String value;

  bool matches(_WechatRuleSource source) {
    final sourceValue = _normalize(source.valueFor(field));
    return switch (operator) {
      'contains' => sourceValue.contains(value),
      'equals' => sourceValue == value,
      _ => false,
    };
  }
}

class _WechatRuleSource {
  const _WechatRuleSource({
    required this.transactionType,
    required this.counterparty,
    required this.product,
    required this.status,
  });

  final String? transactionType;
  final String? counterparty;
  final String? product;
  final String? status;

  String? valueFor(_WechatRuleField field) {
    return switch (field) {
      _WechatRuleField.transactionType => transactionType,
      _WechatRuleField.counterparty => counterparty,
      _WechatRuleField.product => product,
      _WechatRuleField.status => status,
    };
  }
}

enum _WechatRuleField { transactionType, counterparty, product, status }

class _WechatFallbackRule {
  const _WechatFallbackRule({
    required this.id,
    required this.direction,
    required this.categoryPath,
  });

  factory _WechatFallbackRule.fromJson(Map<String, Object?> json) {
    return _WechatFallbackRule(
      id: json['id']! as String,
      direction: _direction(json['direction']! as String),
      categoryPath: List.unmodifiable(
        (json['categoryPath']! as List<Object?>).cast<String>(),
      ),
    );
  }

  final String id;
  final ImportCategoryKind direction;
  final List<String> categoryPath;
}

List<String> _categoryPath(Map<String, Object?> json) {
  return List.unmodifiable(
    (json['categoryPath']! as List<Object?>).cast<String>(),
  );
}

ImportCategoryKind _direction(String value) {
  return switch (value) {
    'income' => ImportCategoryKind.income,
    'expense' => ImportCategoryKind.expense,
    _ => throw FormatException('Unsupported WeChat category direction: $value'),
  };
}

_WechatRuleField _field(String value) {
  return switch (value) {
    'transactionType' => _WechatRuleField.transactionType,
    'counterparty' => _WechatRuleField.counterparty,
    'product' => _WechatRuleField.product,
    'status' => _WechatRuleField.status,
    _ => throw FormatException('Unsupported WeChat lexicon field: $value'),
  };
}

String _normalize(String? value) {
  if (value == null) return '';
  final normalized = StringBuffer();
  for (final rune in value.trim().runes) {
    if (rune == 0x3000) {
      normalized.writeCharCode(0x20);
    } else if (rune >= 0xFF01 && rune <= 0xFF5E) {
      normalized.writeCharCode(rune - 0xFEE0);
    } else {
      normalized.writeCharCode(rune);
    }
  }
  return normalized.toString().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
