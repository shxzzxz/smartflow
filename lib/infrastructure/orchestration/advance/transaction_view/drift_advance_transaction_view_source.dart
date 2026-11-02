import 'package:drift/drift.dart';

import '../../../../application/orchestration/advance/query/advance_transaction_view_read_models.dart';
import '../../../../application/orchestration/advance/query/port/advance_transaction_view_source.dart';
import '../../../../core/money/money.dart';
import '../../../../domain/orchestration/valobj/advance_enums.dart';
import '../../../database/app_database.dart';

final class DriftAdvanceTransactionViewSource
    implements AdvanceTransactionViewSource {
  const DriftAdvanceTransactionViewSource(this._db);

  final AppDatabase _db;

  @override
  Future<AdvanceTransactionViewAnchorPage> findAnchorPage(
    AdvanceTransactionViewQuery query,
  ) async {
    return _pageFromRows(await _anchorSelect(query).get(), query.limit);
  }

  @override
  Stream<AdvanceTransactionViewAnchorPage> watchAnchorPage(
    AdvanceTransactionViewQuery query,
  ) {
    return _anchorSelect(
      query,
    ).watch().map((rows) => _pageFromRows(rows, query.limit));
  }

  @override
  Future<Map<String, AdvanceTransactionViewSummarySource>> findSummaries(
    Set<String> ownerIds,
  ) async {
    return _summaryFromRows(await _summarySelect(ownerIds).get());
  }

  @override
  Stream<Map<String, AdvanceTransactionViewSummarySource>> watchSummaries(
    Set<String> ownerIds,
  ) {
    if (ownerIds.isEmpty) {
      return Stream.value(const {});
    }
    return _summarySelect(ownerIds).watch().map(_summaryFromRows);
  }

  Selectable<QueryRow> _anchorSelect(AdvanceTransactionViewQuery query) {
    final sql = _AdvanceAnchorSql(
      transactionAlias: 'anchor',
      itemIdExpression: 'anchor.owner_id',
    )..apply(query);
    return _db.customSelect(
      '''
SELECT
  anchor.id AS anchor_transaction_id,
  anchor.occurred_at AS anchor_at,
  anchor.owner_id AS item_id
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

  Selectable<QueryRow> _summarySelect(Set<String> ownerIds) {
    final ids = ownerIds.toList()..sort();
    final placeholders = List.filled(ids.length, '?').join(', ');
    return _db.customSelect(
      '''
SELECT
  advance_case.id AS owner_id,
  advance_case.scenario,
  advance_case.tracking_mode,
  advance_case.aa_people_count,
  COALESCE(SUM(
    CASE
      WHEN txn.parent_transaction_id IS NULL
        AND line.role = 'receivable'
      THEN line.amount_minor ELSE 0
    END
  ), 0) AS advance_amount,
  COALESCE(SUM(
    CASE
      WHEN txn.parent_transaction_id IS NOT NULL
        AND txn.business_purpose = 'refund'
        AND line.role = 'receivable'
      THEN line.amount_minor ELSE 0
    END
  ), 0) AS refunded_advance_amount,
  COALESCE(SUM(
    CASE
      WHEN txn.parent_transaction_id IS NOT NULL
        AND txn.business_purpose IN (
          'advanceCollection',
          'advanceSettlement'
        )
        AND line.role = 'settlementIn'
      THEN line.amount_minor ELSE 0
    END
  ), 0) AS received_amount,
  MAX(
    CASE
      WHEN txn.parent_transaction_id IS NOT NULL
        AND txn.business_purpose = 'advanceSettlement'
      THEN 1 ELSE 0
    END
  ) AS is_closed
FROM advance_cases advance_case
LEFT JOIN transactions txn
  ON txn.owner_type = ?
  AND txn.owner_id = advance_case.id
LEFT JOIN transaction_lines line ON line.transaction_id = txn.id
WHERE advance_case.id IN ($placeholders)
GROUP BY advance_case.id
''',
      variables: [
        const Variable<String>(orchestrationAdvanceOwnerType),
        for (final id in ids) Variable<String>(id),
      ],
      readsFrom: {_db.advanceCases, _db.transactions, _db.transactionLines},
    );
  }

  Map<String, AdvanceTransactionViewSummarySource> _summaryFromRows(
    List<QueryRow> rows,
  ) {
    return {
      for (final row in rows)
        row.read<String>('owner_id'): AdvanceTransactionViewSummarySource(
          ownerId: row.read<String>('owner_id'),
          scenario: AdvanceScenario.values.byName(row.read<String>('scenario')),
          trackingMode: AdvanceTrackingMode.values.byName(
            row.read<String>('tracking_mode'),
          ),
          advanceAmount: Money(minorUnits: row.read<int>('advance_amount')),
          refundedAdvanceAmount: Money(
            minorUnits: row.read<int>('refunded_advance_amount'),
          ),
          receivedAmount: Money(minorUnits: row.read<int>('received_amount')),
          isClosed: row.read<int>('is_closed') != 0,
          aaPeopleCount: row.read<int?>('aa_people_count'),
        ),
    };
  }

  AdvanceTransactionViewAnchorPage _pageFromRows(
    List<QueryRow> rows,
    int limit,
  ) {
    return AdvanceTransactionViewAnchorPage(
      hasMore: rows.length > limit,
      anchors: [
        for (final row in rows.take(limit + 1))
          AdvanceTransactionViewAnchorCandidate(
            ownerId: row.read<String>('item_id'),
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
    required this.itemIdExpression,
  });

  final String transactionAlias;
  final String itemIdExpression;
  final List<String> _conditions = [];
  final List<Variable> _variables = [];

  List<Variable> get variables => List.unmodifiable(_variables);

  void apply(AdvanceTransactionViewQuery query) {
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
