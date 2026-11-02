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
      itemIdExpression: 'plan.id',
      planAlias: 'plan',
    )..apply(query);
    return _db.customSelect(
      '''
SELECT
  anchor.id AS anchor_transaction_id,
  anchor.occurred_at AS anchor_at,
  plan.id AS item_id
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
            planId: row.read<String>('item_id'),
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
    required this.itemIdExpression,
    required this.planAlias,
  });

  final String transactionAlias;
  final String itemIdExpression;
  final String planAlias;
  final List<String> _conditions = [];
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
        before.itemType,
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
          '($transactionAlias.occurred_at = ? AND $itemIdExpression < ?))',
        );
        _variables
          ..add(Variable<DateTime>(before.anchorAt))
          ..add(Variable<DateTime>(before.anchorAt))
          ..add(Variable<String>(before.planId));
      }
    }

    final categories = query.categoryAccountIds;
    if (categories != null) {
      if (categories.isEmpty) {
        _conditions.add('0 = 1');
      } else {
        final placeholders = _placeholders(categories.length);
        _variables.addAll(_stringVariables(categories));
        _conditions.add(
          'EXISTS (SELECT 1 FROM amortization_allocations category_match '
          'WHERE category_match.subject_type = \'plan\' '
          'AND category_match.subject_id = $planAlias.id '
          'AND category_match.dimension = \'category\' '
          'AND category_match.account_id IN ($placeholders))',
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
        _conditions.add('0 = 1');
      } else {
        final placeholders = _placeholders(tags.length);
        _variables.addAll(_stringVariables(tags));
        _conditions.add(
          'EXISTS (SELECT 1 FROM transaction_tags tag_match '
          'WHERE tag_match.transaction_id = $transactionAlias.id '
          'AND tag_match.tag_id IN ($placeholders))',
        );
      }
    } else if (query.untaggedOnly) {
      _conditions.add(
        'NOT EXISTS (SELECT 1 FROM transaction_tags tag_match '
        'WHERE tag_match.transaction_id = $transactionAlias.id)',
      );
    }

    final counterpartyId = query.counterpartyId;
    if (counterpartyId != null) {
      _conditions.add('$transactionAlias.counterparty_id = ?');
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
      _conditions.add('0 = 1');
      return;
    }
    final placeholders = _placeholders(accountIds.length);
    _variables.addAll(_stringVariables(accountIds));
    final rolePlaceholders = roles
        .map((role) => "'${role.replaceAll("'", "''")}'")
        .join(', ');
    _conditions.add(
      'EXISTS (SELECT 1 FROM transaction_lines $alias '
      'WHERE $alias.transaction_id = $transactionAlias.id '
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
