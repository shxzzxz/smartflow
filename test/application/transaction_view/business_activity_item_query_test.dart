import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_port_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';

void main() {
  test('batches one source call and preserves unknown items', () async {
    final source = _ItemSource();
    final query = BusinessActivityItemQueryImpl(sources: [source]);
    final first = _transaction(
      'first',
      ownerType: orchestrationAdvanceOwnerType,
    );
    final second = _transaction(
      'second',
      ownerType: orchestrationAdvanceOwnerType,
    );
    final unknown = _transaction('unknown', ownerType: 'unknown.owner');
    final ordinary = _transaction('ordinary');

    final items = await query.findItems([first, second, unknown, ordinary]);

    expect(source.calls, 1);
    expect(source.requestedTransactionIds, {'first', 'second'});
    expect(items['first'], isA<AdvanceBusinessActivityItem>());
    expect(items['second'], isA<UnknownBusinessActivityItem>());
    expect(items['unknown'], isA<UnknownBusinessActivityItem>());
    expect(items, isNot(contains('ordinary')));
    expect(items, isNot(contains('outside-request')));
  });

  test('watchItems emits only the requested transaction projection', () async {
    final source = _ItemSource();
    final query = BusinessActivityItemQueryImpl(sources: [source]);
    final transaction = _transaction(
      'first',
      ownerType: orchestrationAdvanceOwnerType,
    );

    final items = await query.watchItems([transaction]).first;

    expect(items.keys, {'first'});
    expect(items['first'], isA<AdvanceBusinessActivityItem>());
  });
}

final class _ItemSource extends BusinessActivityItemSource {
  var calls = 0;
  var requestedTransactionIds = <String>{};

  @override
  Set<String> get supportedOwnerTypes => const {orchestrationAdvanceOwnerType};

  @override
  Future<Map<String, BusinessActivityItem>> findItems(
    Iterable<TransactionReadModel> transactions,
  ) async {
    calls += 1;
    requestedTransactionIds = {
      for (final transaction in transactions) transaction.id,
    };
    return {
      'first': const AdvanceBusinessActivityItem(
        activityKey: BusinessActivityKey(
          type: orchestrationAdvanceOwnerType,
          id: 'owner-1',
        ),
        transactionId: 'first',
        factKind: AdvanceTransactionFactKind.advance,
        scenario: AdvanceScenario.reimbursement,
        trackingMode: AdvanceTrackingMode.itemized,
      ),
      'outside-request': const AdvanceBusinessActivityItem(
        activityKey: BusinessActivityKey(
          type: orchestrationAdvanceOwnerType,
          id: 'owner-1',
        ),
        transactionId: 'outside-request',
        factKind: AdvanceTransactionFactKind.advance,
        scenario: AdvanceScenario.reimbursement,
        trackingMode: AdvanceTrackingMode.itemized,
      ),
    };
  }

  @override
  Stream<Object?> watchOwnerChanges(String ownerId) => Stream.value(null);
}

TransactionReadModel _transaction(String id, {String? ownerType}) {
  return TransactionReadModel(
    id: id,
    businessPurpose: BusinessPurpose.advance,
    occurredAt: DateTime(2026, 1),
    primaryAmount: const Money(minorUnits: 100),
    ownership: ownerType == null
        ? null
        : TransactionOwnership(ownerType: ownerType, ownerId: 'owner-1'),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
  );
}
