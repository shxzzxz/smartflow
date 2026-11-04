import 'package:drift/drift.dart';

import '../../../../application/orchestration/amortization/query/amortization_transaction_view_read_models.dart';
import '../../../../application/orchestration/amortization/query/port/amortization_transaction_view_source.dart';
import '../../../../domain/orchestration/valobj/amortization_enums.dart';
import '../../../database/app_database.dart';

final class DriftAmortizationTransactionViewSource
    implements AmortizationTransactionViewSource {
  const DriftAmortizationTransactionViewSource(this._db);

  final AppDatabase _db;

  @override
  Future<AmortizationTransactionViewAnchorPage> findAnchorPage(
    AmortizationTransactionViewQuery query,
  ) async {
    return _pageFromRows(await _anchorSelect(query).get(), query.limit);
  }

  @override
  Stream<AmortizationTransactionViewAnchorPage> watchAnchorPage(
    AmortizationTransactionViewQuery query,
  ) {
    return _anchorSelect(
      query,
    ).watch().map((rows) => _pageFromRows(rows, query.limit));
  }

  Selectable<QueryRow> _anchorSelect(AmortizationTransactionViewQuery query) {
    final sql = _AmortizationAnchorSql(
      transactionAlias: 'anchor',
      activityIdExpression: 'plan.id',
      planAlias: 'plan',
    )..apply(query);
    return _db.customSelect(
      '''
SELECT
  anchor.id AS anchor_transaction_id,
  anchor.occurred_at AS anchor_at,
  plan.id AS activity_id
FROM amortization_plans plan
JOIN transactions anchor ON anchor.id = plan.initial_transaction_id
WHERE anchor.parent_transaction_id IS NULL
  AND anchor.owner_type = '$orchestrationAmortizationOwnerType'
  AND anchor.owner_id = plan.id
  AND ${sql.whereClause}
ORDER BY anchor.occurred_at DESC, plan.id DESC
LIMIT ?
''',
      variables: [...sql.variables, Variable<int>(query.limit + 1)],
      readsFrom: {
        _db.transactions,
        _db.transactionLines,
        _db.transactionTags,
        _db.amortizationPlans,
        _db.amortizationPeriods,
        _db.amortizationRefunds,
        _db.amortizationTerminations,
        _db.amortizationAllocations,
      },
    );
  }

  AmortizationTransactionViewAnchorPage _pageFromRows(
    List<QueryRow> rows,
    int limit,
  ) {
    return AmortizationTransactionViewAnchorPage(
      hasMore: rows.length > limit,
      anchors: [
        for (final row in rows.take(limit + 1))
          AmortizationTransactionViewAnchorCandidate(
            planId: row.read<String>('activity_id'),
            anchorTransactionId: row.read<String>('anchor_transaction_id'),
            anchorAt: row.read<DateTime>('anchor_at'),
          ),
      ],
    );
  }
}

final class _AmortizationAnchorSql {
  _AmortizationAnchorSql({
    required this.transactionAlias,
    required this.activityIdExpression,
    required this.planAlias,
  });

  final String transactionAlias;
  final String activityIdExpression;
  final String planAlias;
  final List<String> _conditions = [];
  final List<String> _eventConditions = [];
  final List<Variable> _variables = [];

  List<Variable> get variables => List.unmodifiable(_variables);

  void apply(AmortizationTransactionViewQuery query) {
    _conditions.add(
      '($transactionAlias.occurred_at >= ? AND '
      '$transactionAlias.occurred_at < ?)',
    );
    _variables
      ..add(Variable<DateTime>(query.occurredFrom))
      ..add(Variable<DateTime>(query.occurredUntil));

    final before = query.before;
    if (before != null) {
      final comparison = orchestrationAmortizationOwnerType.compareTo(
        before.activityType,
      );
      if (comparison < 0) {
        _conditions.add('$transactionAlias.occurred_at <= ?');
        _variables.add(Variable<DateTime>(before.anchorAt));
      } else if (comparison > 0) {
        _conditions.add('$transactionAlias.occurred_at < ?');
        _variables.add(Variable<DateTime>(before.anchorAt));
      } else {
        _conditions.add(
          '($transactionAlias.occurred_at < ? OR '
          '($transactionAlias.occurred_at = ? AND $activityIdExpression < ?))',
        );
        _variables
          ..add(Variable<DateTime>(before.anchorAt))
          ..add(Variable<DateTime>(before.anchorAt))
          ..add(Variable<String>(before.planId));
      }
    }

    _applyEventFilters(query);
    if (_eventConditions.isNotEmpty) {
      final eventConditions = _eventConditions.join(' AND ');
      _conditions.add(
        'EXISTS (SELECT 1 FROM transactions event '
        'WHERE event.parent_transaction_id IS NULL '
        'AND event.owner_type = \'$orchestrationAmortizationOwnerType\' '
        'AND event.owner_id = $planAlias.id '
        'AND $eventConditions)',
      );
    }
  }

  void _applyEventFilters(AmortizationTransactionViewQuery query) {
    final categories = query.categoryAccountIds;
    if (categories != null) {
      if (categories.isEmpty) {
        _eventConditions.add('0 = 1');
      } else {
        final placeholders = _placeholders(categories.length);
        _variables.addAll(_stringVariables(categories));
        _variables.addAll(_stringVariables(categories));
        _eventConditions.add(
          '('
          'EXISTS (SELECT 1 FROM amortization_terminations recognition '
          'WHERE recognition.recognition_transaction_id = event.id '
          'AND EXISTS (SELECT 1 FROM transaction_lines category_line '
          'WHERE category_line.transaction_id = event.id '
          'AND category_line.role = \'category\' '
          'AND category_line.account_id IN ($placeholders))) '
          'OR EXISTS (SELECT 1 FROM amortization_allocations category_match '
          'WHERE category_match.dimension = \'category\' '
          'AND category_match.account_id IN ($placeholders) '
          'AND ('
          '(category_match.subject_type = \'plan\' '
          'AND category_match.subject_id = $planAlias.id '
          'AND event.id = $planAlias.initial_transaction_id) '
          'OR (category_match.subject_type = \'period\' '
          'AND EXISTS (SELECT 1 FROM amortization_periods period_match '
          'WHERE period_match.id = category_match.subject_id '
          'AND period_match.transaction_id = event.id)) '
          'OR (category_match.subject_type = \'refund\' '
          'AND EXISTS (SELECT 1 FROM amortization_refunds refund_match '
          'WHERE refund_match.id = category_match.subject_id '
          'AND refund_match.transfer_transaction_id = event.id)) '
          'OR (category_match.subject_type = \'termination\' '
          'AND EXISTS (SELECT 1 FROM amortization_terminations termination_match '
          'WHERE termination_match.id = category_match.subject_id '
          'AND termination_match.return_transaction_id = event.id))'
          '))'
          ')',
        );
      }
    }

    final settlements = query.settlementAccountIds;
    if (settlements != null) {
      _transactionLineFilter(
        settlements,
        roles: const {'settlementIn', 'settlementOut'},
        alias: 'amortization_settlement_lines',
      );
    }

    final tags = query.tagIds;
    if (tags != null) {
      if (tags.isEmpty) {
        _eventConditions.add('0 = 1');
      } else {
        final placeholders = _placeholders(tags.length);
        _variables.addAll(_stringVariables(tags));
        _eventConditions.add(
          'EXISTS (SELECT 1 FROM transaction_tags tag_match '
          'WHERE tag_match.transaction_id = event.id '
          'AND tag_match.tag_id IN ($placeholders))',
        );
      }
    } else if (query.untaggedOnly) {
      _eventConditions.add(
        'NOT EXISTS (SELECT 1 FROM transaction_tags tag_match '
        'WHERE tag_match.transaction_id = event.id)',
      );
    }

    final counterpartyId = query.counterpartyId;
    if (counterpartyId != null) {
      _eventConditions.add('event.counterparty_id = ?');
      _variables.add(Variable<String>(counterpartyId));
    }
  }

  String get whereClause => _conditions.join(' AND ');

  void _transactionLineFilter(
    Set<String> accountIds, {
    required Set<String> roles,
    required String alias,
  }) {
    if (accountIds.isEmpty) {
      _eventConditions.add('0 = 1');
      return;
    }
    final placeholders = _placeholders(accountIds.length);
    _variables.addAll(_stringVariables(accountIds));
    final rolePlaceholders = roles
        .map((role) => "'${role.replaceAll("'", "''")}'")
        .join(', ');
    _eventConditions.add(
      'EXISTS (SELECT 1 FROM transaction_lines $alias '
      'WHERE $alias.transaction_id = event.id '
      'AND $alias.role IN ($rolePlaceholders) '
      'AND $alias.account_id IN ($placeholders))',
    );
  }
}

List<Variable<String>> _stringVariables(Iterable<String> values) {
  final sorted = values.toSet().toList()..sort();
  return [for (final value in sorted) Variable<String>(value)];
}

String _placeholders(int count) => List.filled(count, '?').join(', ');
