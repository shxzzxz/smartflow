import 'package:drift/drift.dart';

import '../../../application/transaction_view/transaction_view_query_port_api.dart';
import '../../database/app_database.dart';
import 'business_activity_query_support.dart';

/// Ownerless top-level transactions are ordinary ledger business activities.
final class DriftLedgerBusinessActivitySource
    implements BusinessActivitySource {
  const DriftLedgerBusinessActivitySource(this._db);

  final AppDatabase _db;

  @override
  String get sourceKey => 'ledger';

  @override
  Set<String> get supportedActivityTypes => const {
    ledgerTransactionGroupActivityType,
  };

  @override
  Future<BusinessActivitySourcePage> findAnchorPage(
    BusinessActivityPageQuery query,
  ) async {
    return businessActivitySourcePageFromRows(
      await _select(query).get(),
      limit: query.limit,
    );
  }

  @override
  Stream<BusinessActivitySourcePage> watchAnchorPage(
    BusinessActivityPageQuery query,
  ) {
    return _select(query).watch().map(
      (rows) => businessActivitySourcePageFromRows(rows, limit: query.limit),
    );
  }

  @override
  Future<Map<BusinessActivityKey, BusinessActivitySummary>> findSummaries(
    Iterable<BusinessActivityAnchorCandidate> anchors,
  ) async {
    return {
      for (final anchor in anchors)
        if (anchor.activityKey.type == ledgerTransactionGroupActivityType)
          anchor.activityKey: const LedgerBusinessActivitySummary(),
    };
  }

  Selectable<QueryRow> _select(BusinessActivityPageQuery query) {
    final sql = BusinessActivityAnchorSql(
      transactionAlias: 'anchor',
      activityType: ledgerTransactionGroupActivityType,
      activityIdExpression: 'anchor.id',
    )..apply(query);
    return _db.customSelect(
      '''
SELECT
  anchor.id AS anchor_transaction_id,
  anchor.occurred_at AS anchor_at,
  '$ledgerTransactionGroupActivityType' AS activity_type,
  anchor.id AS activity_id
FROM transactions anchor
WHERE anchor.parent_transaction_id IS NULL
  AND anchor.owner_type IS NULL
  AND anchor.owner_id IS NULL
  AND ${sql.whereClause}
ORDER BY anchor.occurred_at DESC, anchor.id DESC
LIMIT ?
''',
      variables: [...sql.variables, Variable<int>(query.limit + 1)],
      readsFrom: {_db.transactions, _db.transactionLines, _db.transactionTags},
    );
  }
}
