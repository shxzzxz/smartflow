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
  Future<BusinessActivitySourcePage> findCandidatePage(
    BusinessActivityPageQuery query,
  ) async {
    return businessActivitySourcePageFromRows(
      await _select(query).get(),
      limit: query.limit,
    );
  }

  @override
  Stream<BusinessActivitySourcePage> watchCandidatePage(
    BusinessActivityPageQuery query,
  ) {
    return _select(query).watch().map(
      (rows) => businessActivitySourcePageFromRows(rows, limit: query.limit),
    );
  }

  @override
  Future<Map<BusinessActivityKey, BusinessActivitySummary>> findSummaries(
    Iterable<BusinessActivityCandidate> candidates,
  ) async {
    return {
      for (final candidate in candidates)
        if (candidate.activityKey.type == ledgerTransactionGroupActivityType)
          candidate.activityKey: const LedgerBusinessActivitySummary(),
    };
  }

  @override
  Stream<Map<BusinessActivityKey, BusinessActivitySummary>> watchSummaries(
    Iterable<BusinessActivityCandidate> candidates,
  ) {
    return Stream.fromFuture(findSummaries(candidates));
  }

  Selectable<QueryRow> _select(BusinessActivityPageQuery query) {
    final sql = BusinessActivityCandidateSql(
      displayTransactionAlias: 'display_transaction',
      activityAtExpression: 'display_transaction.occurred_at',
      activityType: ledgerTransactionGroupActivityType,
      activityIdExpression: 'display_transaction.id',
    )..apply(query);
    return _db.customSelect(
      '''
SELECT
  display_transaction.id AS display_transaction_id,
  display_transaction.occurred_at AS activity_at,
  '$ledgerTransactionGroupActivityType' AS activity_type,
  display_transaction.id AS activity_id
FROM transactions display_transaction
WHERE display_transaction.parent_transaction_id IS NULL
  AND display_transaction.owner_type IS NULL
  AND display_transaction.owner_id IS NULL
  AND ${sql.whereClause}
ORDER BY display_transaction.occurred_at DESC, display_transaction.id DESC
LIMIT ?
''',
      variables: [...sql.variables, Variable<int>(query.limit + 1)],
      readsFrom: {_db.transactions, _db.transactionLines, _db.transactionTags},
    );
  }
}
