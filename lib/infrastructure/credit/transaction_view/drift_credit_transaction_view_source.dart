import 'package:drift/drift.dart';

import '../../../application/credit/transaction_view/query/credit_transaction_view_read_models.dart';
import '../../../application/credit/transaction_view/query/port/credit_transaction_view_source.dart';
import '../../../domain/credit/valobj/installment_enums.dart';
import '../../../domain/credit/valobj/repayment_enums.dart';
import '../../database/app_database.dart';

final class DriftCreditTransactionViewSource
    implements CreditTransactionViewSource {
  const DriftCreditTransactionViewSource(this._db);

  final AppDatabase _db;

  @override
  Future<CreditTransactionViewAnchorPage> findAnchorPage(
    CreditTransactionViewQuery query,
  ) async {
    return _pageFromRows(await _anchorSelect(query).get(), query.limit);
  }

  @override
  Stream<CreditTransactionViewAnchorPage> watchAnchorPage(
    CreditTransactionViewQuery query,
  ) {
    return _anchorSelect(
      query,
    ).watch().map((rows) => _pageFromRows(rows, query.limit));
  }

  @override
  Future<Map<String, CreditRepaymentBusinessActivitySummary>>
  findRepaymentSummaries(Set<String> repaymentIds) async {
    if (repaymentIds.isEmpty) return const {};
    final ids = repaymentIds.toList()..sort();
    final rows = await _db
        .customSelect(
          '''
SELECT id, repayment_type, target_type, target_id
FROM repayments
WHERE id IN (${_placeholders(ids.length)})
''',
          variables: _variables(ids),
          readsFrom: {_db.repayments},
        )
        .get();
    return {
      for (final row in rows)
        row.read<String>(
          'id',
        ): CreditRepaymentBusinessActivitySummary.fromRepayment(
          repaymentId: row.read<String>('id'),
          repaymentType: RepaymentType.fromCode(
            row.read<String>('repayment_type'),
          ),
          targetType: RepaymentTargetType.fromCode(
            row.read<String>('target_type'),
          ),
          targetId: row.read<String>('target_id'),
        ),
    };
  }

  Selectable<QueryRow> _anchorSelect(CreditTransactionViewQuery query) {
    final requestedTypes = query.activityTypes;
    final branches = <String>[];
    final variables = <Variable>[];

    if (requestedTypes == null ||
        requestedTypes.contains(
          CreditTransactionViewActivityType.installment,
        )) {
      final sql = _AnchorSql(
        transactionAlias: 'anchor',
        activityType: CreditTransactionViewActivityType.installment.code,
        activityIdExpression: 'contract.id',
      )..apply(query);
      branches.add('''
SELECT
  anchor.id AS anchor_transaction_id,
  anchor.occurred_at AS anchor_at,
  '${CreditTransactionViewActivityType.installment.code}' AS activity_type,
  contract.id AS activity_id
FROM installment_contracts contract
JOIN transactions anchor ON anchor.id = contract.source_ref_id
WHERE contract.source_ref_id IS NOT NULL
  AND contract.installment_type IN ('disbursement', 'purchase')
  AND anchor.parent_transaction_id IS NULL
  AND anchor.owner_type = '$installmentOwnerType'
  AND anchor.owner_id = contract.id
  AND ${sql.whereClause}
''');
      variables.addAll(sql.variables);
    }

    if (requestedTypes == null ||
        requestedTypes.contains(CreditTransactionViewActivityType.repayment)) {
      final sql = _AnchorSql(
        transactionAlias: 'anchor',
        activityType: CreditTransactionViewActivityType.repayment.code,
        activityIdExpression: 'repayment.id',
      )..apply(query);
      branches.add('''
SELECT
  anchor.id AS anchor_transaction_id,
  anchor.occurred_at AS anchor_at,
  '${CreditTransactionViewActivityType.repayment.code}' AS activity_type,
  repayment.id AS activity_id
FROM repayments repayment
JOIN transactions anchor ON anchor.id = repayment.transaction_id
WHERE repayment.repayment_type IN (
  '${RepaymentType.bill.code}',
  '${RepaymentType.unattributed.code}'
)
  AND anchor.parent_transaction_id IS NULL
  AND anchor.owner_type = '$creditRepaymentOwnerType'
  AND anchor.owner_id = repayment.id
  AND ${sql.whereClause}
''');
      variables.addAll(sql.variables);
    }

    if (branches.isEmpty) {
      return _db.customSelect(
        'SELECT NULL AS anchor_transaction_id, NULL AS anchor_at, '
        'NULL AS activity_type, NULL AS activity_id WHERE 0 = 1',
      );
    }

    return _db.customSelect(
      '''
SELECT *
FROM (
  ${branches.join('\nUNION ALL\n')}
)
ORDER BY anchor_at DESC, activity_type DESC, activity_id DESC
LIMIT ?
''',
      variables: [...variables, Variable<int>(query.limit + 1)],
      readsFrom: {
        _db.transactions,
        _db.transactionLines,
        _db.transactionTags,
        _db.installmentContracts,
        _db.repayments,
      },
    );
  }

  CreditTransactionViewAnchorPage _pageFromRows(
    List<QueryRow> rows,
    int limit,
  ) {
    return CreditTransactionViewAnchorPage(
      hasMore: rows.length > limit,
      anchors: [
        for (final row in rows.take(limit + 1))
          CreditTransactionViewAnchorCandidate(
            activityType: CreditTransactionViewActivityType.values.firstWhere(
              (value) => value.code == row.read<String>('activity_type'),
            ),
            activityId: row.read<String>('activity_id'),
            anchorTransactionId: row.read<String>('anchor_transaction_id'),
            anchorAt: row.read<DateTime>('anchor_at'),
          ),
      ],
    );
  }
}

final class _AnchorSql {
  _AnchorSql({
    required this.transactionAlias,
    required this.activityType,
    required this.activityIdExpression,
  });

  final String transactionAlias;
  final String activityType;
  final String activityIdExpression;
  final List<String> _conditions = [];
  final List<Variable> _variables = [];

  List<Variable> get variables => List.unmodifiable(_variables);

  void apply(CreditTransactionViewQuery query) {
    _conditions.add(
      '($transactionAlias.occurred_at >= ? AND '
      '$transactionAlias.occurred_at < ?)',
    );
    _variables
      ..add(Variable<DateTime>(query.occurredFrom))
      ..add(Variable<DateTime>(query.occurredUntil));

    final before = query.before;
    if (before != null) _applyCursor(before);

    final categories = query.categoryAccountIds;
    if (categories != null) {
      _transactionLineFilter(
        categories,
        roles: const {'category', 'advanceExpenseCategory', 'advanceSelfBorne'},
        alias: 'credit_category_lines',
      );
    }

    final settlements = query.settlementAccountIds;
    if (settlements != null) {
      _transactionLineFilter(
        settlements,
        roles: const {'settlementIn', 'settlementOut'},
        alias: 'credit_settlement_lines',
      );
    }

    final tags = query.tagIds;
    if (tags != null) {
      if (tags.isEmpty) {
        _conditions.add('0 = 1');
      } else {
        final placeholders = _placeholders(tags.length);
        _variables.addAll(_variablesFor(tags));
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

  void _applyCursor(CreditTransactionViewCursor before) {
    final comparison = activityType.compareTo(before.activityType);
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
        ..add(Variable<String>(before.activityId));
    }
  }

  void _transactionLineFilter(
    Set<String> accountIds, {
    required Set<String> roles,
    required String alias,
  }) {
    if (accountIds.isEmpty) {
      _conditions.add('0 = 1');
      return;
    }
    final accountPlaceholders = _placeholders(accountIds.length);
    _variables.addAll(_variablesFor(accountIds));
    final rolePlaceholders = roles
        .map((role) => "'${role.replaceAll("'", "''")}'")
        .join(', ');
    _conditions.add(
      'EXISTS (SELECT 1 FROM transaction_lines $alias '
      'WHERE $alias.transaction_id = $transactionAlias.id '
      'AND $alias.role IN ($rolePlaceholders) '
      'AND $alias.account_id IN ($accountPlaceholders))',
    );
  }
}

List<Variable<String>> _variablesFor(Iterable<String> values) {
  final sorted = values.toSet().toList()..sort();
  return [for (final value in sorted) Variable<String>(value)];
}

List<Variable<String>> _variables(Iterable<String> values) =>
    _variablesFor(values);

String _placeholders(int count) => List.filled(count, '?').join(', ');
