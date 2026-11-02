import 'package:drift/drift.dart';

import '../../../application/transaction_view/transaction_view_query_port_api.dart';
import '../../database/app_database.dart';
import 'business_item_query_support.dart';

/// Ownerless top-level transactions are ordinary ledger business items.
final class DriftLedgerBusinessItemSource implements BusinessItemSource {
  const DriftLedgerBusinessItemSource(this._db);

  final AppDatabase _db;

  @override
  String get sourceKey => 'ledger';

  @override
  Set<String> get supportedItemTypes => const {ledgerTransactionGroupItemType};

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
    return {
      for (final key in itemKeys)
        if (key.type == ledgerTransactionGroupItemType)
          key: const LedgerBusinessItemSummary(),
    };
  }

  Selectable<QueryRow> _select(BusinessItemPageQuery query) {
    final sql = BusinessItemAnchorSql(
      transactionAlias: 'anchor',
      itemType: ledgerTransactionGroupItemType,
      itemIdExpression: 'anchor.id',
    )..apply(query);
    return _db.customSelect(
      '''
SELECT
  anchor.id AS anchor_transaction_id,
  anchor.occurred_at AS anchor_at,
  '$ledgerTransactionGroupItemType' AS item_type,
  anchor.id AS item_id
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
