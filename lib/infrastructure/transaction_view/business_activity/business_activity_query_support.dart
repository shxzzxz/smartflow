import 'package:drift/drift.dart';

import '../../../application/transaction_view/business_activity/query/business_activity_queries.dart';

/// Builds the common anchor predicate used by business-activity sources.
///
/// Source implementations provide the item identity and any owner/plan join
/// predicate. All business filters, time bounds and the cursor are appended
/// here so every source applies them before its own `LIMIT`.
final class BusinessActivityAnchorSql {
  BusinessActivityAnchorSql({
    required this.transactionAlias,
    required this.activityType,
    required this.activityIdExpression,
    this.amortizationPlanAlias,
  });

  final String transactionAlias;
  final String activityType;
  final String activityIdExpression;
  final String? amortizationPlanAlias;

  final List<String> _conditions = [];
  final List<Variable> _variables = [];

  List<Variable> get variables => List.unmodifiable(_variables);

  void addCondition(String condition) {
    _conditions.add('($condition)');
  }

  void apply(BusinessActivityPageQuery query) {
    addCondition(
      '$transactionAlias.occurred_at >= ? AND '
      '$transactionAlias.occurred_at < ?',
    );
    _variables
      ..add(Variable<DateTime>(query.occurredFrom))
      ..add(Variable<DateTime>(query.occurredUntil));

    final before = query.before;
    if (before != null) {
      _applyCursor(before);
    }

    final categoryAccountIds = query.categoryAccountIds;
    if (categoryAccountIds != null) {
      _applyCategoryFilter(categoryAccountIds);
    }

    final settlementAccountIds = query.settlementAccountIds;
    if (settlementAccountIds != null) {
      _applyTransactionLineFilter(
        settlementAccountIds,
        roles: const {'settlementIn', 'settlementOut'},
        subqueryAlias: 'business_activity_settlement_lines',
      );
    }

    final tagIds = query.tagIds;
    if (tagIds != null) {
      if (tagIds.isEmpty) {
        addCondition('0 = 1');
      } else {
        final inClause = _inClause(tagIds);
        addCondition(
          'EXISTS (SELECT 1 FROM transaction_tags tag_match '
          'WHERE tag_match.transaction_id = $transactionAlias.id '
          'AND tag_match.tag_id IN ($inClause))',
        );
      }
    } else if (query.untaggedOnly) {
      addCondition(
        'NOT EXISTS (SELECT 1 FROM transaction_tags tag_match '
        'WHERE tag_match.transaction_id = $transactionAlias.id)',
      );
    }

    final counterpartyId = query.counterpartyId;
    if (counterpartyId != null) {
      addCondition('$transactionAlias.counterparty_id = ?');
      _variables.add(Variable<String>(counterpartyId));
    }
  }

  String get whereClause =>
      _conditions.isEmpty ? '1 = 1' : _conditions.join(' AND ');

  void _applyCursor(BusinessActivityCursor before) {
    final typeComparison = activityType.compareTo(before.activityKey.type);
    if (typeComparison < 0) {
      addCondition('$transactionAlias.occurred_at <= ?');
      _variables.add(Variable<DateTime>(before.anchorAt));
      return;
    }
    if (typeComparison > 0) {
      addCondition('$transactionAlias.occurred_at < ?');
      _variables.add(Variable<DateTime>(before.anchorAt));
      return;
    }
    addCondition(
      '$transactionAlias.occurred_at < ? OR '
      '($transactionAlias.occurred_at = ? AND '
      '$activityIdExpression < ?)',
    );
    _variables
      ..add(Variable<DateTime>(before.anchorAt))
      ..add(Variable<DateTime>(before.anchorAt))
      ..add(Variable<String>(before.activityKey.id));
  }

  void _applyCategoryFilter(Set<String> accountIds) {
    final planAlias = amortizationPlanAlias;
    if (planAlias != null) {
      if (accountIds.isEmpty) {
        addCondition('0 = 1');
        return;
      }
      final inClause = _inClause(accountIds);
      addCondition(
        'EXISTS (SELECT 1 FROM amortization_allocations category_match '
        'WHERE category_match.subject_type = \'plan\' '
        'AND category_match.subject_id = $planAlias.id '
        'AND category_match.dimension = \'category\' '
        'AND category_match.account_id IN ($inClause))',
      );
      return;
    }
    _applyTransactionLineFilter(
      accountIds,
      roles: const {'category', 'advanceExpenseCategory', 'advanceSelfBorne'},
      subqueryAlias: 'business_activity_category_lines',
    );
  }

  void _applyTransactionLineFilter(
    Set<String> accountIds, {
    required Set<String> roles,
    required String subqueryAlias,
  }) {
    if (accountIds.isEmpty) {
      addCondition('0 = 1');
      return;
    }
    final accountClause = _inClause(accountIds);
    final roleClause = _literalInClause(roles);
    addCondition(
      'EXISTS (SELECT 1 FROM transaction_lines $subqueryAlias '
      'WHERE $subqueryAlias.transaction_id = $transactionAlias.id '
      'AND $subqueryAlias.role IN ($roleClause) '
      'AND $subqueryAlias.account_id IN ($accountClause))',
    );
  }

  String _inClause(Iterable<String> values) {
    final sorted = values.toSet().toList()..sort();
    final placeholders = <String>[];
    for (final value in sorted) {
      placeholders.add('?');
      _variables.add(Variable<String>(value));
    }
    return placeholders.join(', ');
  }

  String _literalInClause(Iterable<String> values) {
    return (values.toSet().toList()..sort())
        .map((value) => "'${value.replaceAll("'", "''")}'")
        .join(', ');
  }
}

BusinessActivitySourcePage businessActivitySourcePageFromRows(
  List<QueryRow> rows, {
  required int limit,
}) {
  final hasMore = rows.length > limit;
  return BusinessActivitySourcePage(
    hasMore: hasMore,
    anchors: [
      for (final row in rows.take(limit + 1))
        BusinessActivityAnchorCandidate(
          activityKey: BusinessActivityKey(
            type: row.read<String>('activity_type'),
            id: row.read<String>('activity_id'),
          ),
          anchorTransactionId: row.read<String>('anchor_transaction_id'),
          anchorAt: row.read<DateTime>('anchor_at'),
        ),
    ],
  );
}

List<Variable<String>> businessActivityStringVariables(
  Iterable<String> values,
) {
  final sorted = values.toSet().toList()..sort();
  return [for (final value in sorted) Variable<String>(value)];
}

String businessActivityPlaceholders(int count) =>
    List.filled(count, '?').join(', ');
