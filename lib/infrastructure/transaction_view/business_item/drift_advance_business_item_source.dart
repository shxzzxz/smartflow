import 'package:drift/drift.dart';

import '../../../application/transaction_view/transaction_view_query_port_api.dart';
import '../../../core/money/money.dart';
import '../../../domain/ledger/entity/transaction_group.dart';
import '../../../domain/orchestration/valobj/advance_enums.dart';
import '../../database/app_database.dart';
import 'business_item_query_support.dart';

final class DriftAdvanceBusinessItemSource implements BusinessItemSource {
  const DriftAdvanceBusinessItemSource(this._db);

  final AppDatabase _db;

  @override
  String get sourceKey => 'advance';

  @override
  Future<BusinessItemSourcePage> findAnchorPage(
    BusinessItemPageQuery query,
  ) async {
    return businessItemSourcePageFromRows(
      await _select(query).get(),
      limit: query.limit,
    );
  }

  @override
  Stream<BusinessItemSourcePage> watchAnchorPage(BusinessItemPageQuery query) {
    return _select(query).watch().map(
      (rows) => businessItemSourcePageFromRows(rows, limit: query.limit),
    );
  }

  @override
  Future<Map<BusinessItemKey, BusinessItemSummary>> findSummaries(
    Set<BusinessItemKey> itemKeys,
  ) async {
    final ownerIds = {
      for (final key in itemKeys)
        if (key.type == orchestrationAdvanceOwnerType) key.id,
    };
    if (ownerIds.isEmpty) return const {};

    final variables = businessItemStringVariables(ownerIds);
    final rows = await _db
        .customSelect(
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
WHERE advance_case.id IN (${businessItemPlaceholders(variables.length)})
GROUP BY advance_case.id
''',
          variables: [
            const Variable<String>(orchestrationAdvanceOwnerType),
            ...variables,
          ],
          readsFrom: {_db.advanceCases, _db.transactions, _db.transactionLines},
        )
        .get();

    return {
      for (final row in rows)
        BusinessItemKey(
          type: orchestrationAdvanceOwnerType,
          id: row.read<String>('owner_id'),
        ): _summaryFromRow(
          row,
        ),
    };
  }

  BusinessItemSummary _summaryFromRow(QueryRow row) {
    final isClosed = row.read<int>('is_closed') != 0;
    return AdvanceBusinessItemSummary(
      scenario: AdvanceScenario.values.byName(row.read<String>('scenario')),
      trackingMode: AdvanceTrackingMode.values.byName(
        row.read<String>('tracking_mode'),
      ),
      outstanding: calculateAdvanceOutstanding(
        advanceAmount: Money(minorUnits: row.read<int>('advance_amount')),
        refundedAdvanceAmount: Money(
          minorUnits: row.read<int>('refunded_advance_amount'),
        ),
        receivedTotal: Money(minorUnits: row.read<int>('received_amount')),
        isClosed: isClosed,
      ),
      isClosed: isClosed,
      aaPeopleCount: row.read<int?>('aa_people_count'),
    );
  }

  Selectable<QueryRow> _select(BusinessItemPageQuery query) {
    final sql = BusinessItemAnchorSql(
      transactionAlias: 'anchor',
      itemType: orchestrationAdvanceOwnerType,
      itemIdExpression: 'anchor.owner_id',
    )..apply(query);
    return _db.customSelect(
      '''
SELECT
  anchor.id AS anchor_transaction_id,
  anchor.occurred_at AS anchor_at,
  '$orchestrationAdvanceOwnerType' AS item_type,
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
}
