import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';

void main() {
  test('reuses ledger query semantics with all transaction hierarchy', () {
    final before = TransactionListCursor(
      occurredAt: DateTime(2026, 10, 12),
      id: 'tx-2',
    );
    final query = TransactionFeedQuery(
      match: const TransactionImpactMatch(
        categoryAccountIds: {'food'},
        settlementAccountIds: {'cash'},
      ),
      occurredFrom: DateTime(2026, 10),
      occurredUntil: DateTime(2026, 11),
      limit: 20,
      before: before,
      tagIds: const {'travel'},
    );

    final result = query.toTransactionListQuery();

    expect(result.match, isA<TransactionImpactMatch>());
    expect(result.match.categoryAccountIds, {'food'});
    expect(result.match.settlementAccountIds, {'cash'});
    expect(result.topLevelOnly, isFalse);
    expect(result.limit, 20);
    expect(result.before, same(before));
    expect(result.tagIds, {'travel'});
  });

  test('supports an explicit top-level ledger impact view', () {
    final query = TransactionFeedQuery(includeChildTransactions: false);

    expect(query.toTransactionListQuery().topLevelOnly, isTrue);
  });
}
