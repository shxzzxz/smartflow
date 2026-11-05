import 'package:drift/drift.dart';

import '../../../../application/orchestration/advance/query/advance_business_activity_read_models.dart';
import '../../../../application/orchestration/advance/query/port/advance_business_activity_source.dart';
import '../../../../domain/orchestration/valobj/advance_enums.dart';
import '../../../database/app_database.dart';

final class DriftAdvanceBusinessActivitySource
    implements AdvanceBusinessActivitySource {
  const DriftAdvanceBusinessActivitySource(this._db);

  final AppDatabase _db;

  @override
  Future<AdvanceBusinessActivityAnchorPage> findAnchorPage(
    AdvanceBusinessActivityQuery query,
  ) async {
    return _pageFromRows(await _anchorSelect(query).get(), query.limit);
  }

  @override
  Stream<AdvanceBusinessActivityAnchorPage> watchAnchorPage(
    AdvanceBusinessActivityQuery query,
  ) {
    return _anchorSelect(
      query,
    ).watch().map((rows) => _pageFromRows(rows, query.limit));
  }

  Selectable<QueryRow> _anchorSelect(AdvanceBusinessActivityQuery query) {
    final sql = _AdvanceAnchorSql(
      transactionAlias: 'anchor',
      activityIdExpression: 'anchor.owner_id',
    )..apply(query);
    return _db.customSelect(
      '''
SELECT
  anchor.id AS anchor_transaction_id,
  anchor.occurred_at AS anchor_at,
  anchor.owner_id AS activity_id
FROM transactions anchor
JOIN advance_cases advance_case ON advance_case.id = anchor.owner_id
WHERE anchor.parent_transaction_id IS NULL
  AND anchor.owner_type = '$orchestrationAdvanceOwnerType'
  AND ${sql.whereClause}
ORDER BY anchor.occurred_at DESC, anchor.owner_id DESC
LIMIT ?
''',
      variables: [...sql.variables, Variable<int>(query.limit + 1)],
      readsFrom: {
        _db.transactions,
        _db.transactionLines,
        _db.transactionTags,
        _db.advanceCases,
      },
    );
  }

  AdvanceBusinessActivityAnchorPage _pageFromRows(
    List<QueryRow> rows,
    int limit,
  ) {
    return AdvanceBusinessActivityAnchorPage(
      hasMore: rows.length > limit,
      anchors: [
        for (final row in rows.take(limit + 1))
          AdvanceBusinessActivityAnchorCandidate(
            ownerId: row.read<String>('activity_id'),
            anchorTransactionId: row.read<String>('anchor_transaction_id'),
            anchorAt: row.read<DateTime>('anchor_at'),
          ),
      ],
    );
  }
}

final class _AdvanceAnchorSql {
  _AdvanceAnchorSql({
    required this.transactionAlias,
    required this.activityIdExpression,
  });

  final String transactionAlias;
  final String activityIdExpression;
  final List<String> _conditions = [];
  final List<Variable> _variables = [];

  List<Variable> get variables => List.unmodifiable(_variables);

  void apply(AdvanceBusinessActivityQuery query) {
    _conditions.add(
      '($transactionAlias.occurred_at >= ? AND '
      '$transactionAlias.occurred_at < ?)',
    );
    _variables
      ..add(Variable<DateTime>(query.occurredFrom))
      ..add(Variable<DateTime>(query.occurredUntil));

    final before = query.before;
    if (before != null) {
      final comparison = orchestrationAdvanceOwnerType.compareTo(
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
          ..add(Variable<String>(before.ownerId));
      }
    }

    final categories = query.categoryAccountIds;
    if (categories != null) {
      _transactionLineFilter(
        categories,
        roles: const {'category', 'advanceExpenseCategory', 'advanceSelfBorne'},
        alias: 'advance_category_lines',
      );
    }

    final settlements = query.settlementAccountIds;
    if (settlements != null) {
      _transactionLineFilter(
        settlements,
        roles: const {'settlementIn', 'settlementOut'},
        alias: 'advance_settlement_lines',
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
