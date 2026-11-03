import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_port_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';

void main() {
  test('batches one source call and preserves unknown contexts', () async {
    final source = _ContextSource();
    final query = TransactionBusinessContextQueryImpl(sources: [source]);
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

    final contexts = await query.findContexts([
      first,
      second,
      unknown,
      ordinary,
    ]);

    expect(source.calls, 1);
    expect(source.requestedTransactionIds, {'first', 'second'});
    expect(contexts['first'], isA<AdvanceTransactionBusinessContext>());
    expect(contexts['second'], isA<UnknownTransactionBusinessContext>());
    expect(contexts['unknown'], isA<UnknownTransactionBusinessContext>());
    expect(contexts, isNot(contains('ordinary')));
  });
}

final class _ContextSource extends TransactionBusinessContextSource {
  var calls = 0;
  var requestedTransactionIds = <String>{};

  @override
  Set<String> get supportedOwnerTypes => const {orchestrationAdvanceOwnerType};

  @override
  Future<Map<String, TransactionBusinessContext>> findContexts(
    Iterable<TransactionReadModel> transactions,
  ) async {
    calls += 1;
    requestedTransactionIds = {
      for (final transaction in transactions) transaction.id,
    };
    return {
      'first': const AdvanceTransactionBusinessContext(
        ownerType: orchestrationAdvanceOwnerType,
        ownerId: 'owner-1',
        scenario: AdvanceScenario.reimbursement,
        trackingMode: AdvanceTrackingMode.itemized,
        advanceAmount: Money(minorUnits: 100),
        receivedAmount: Money(minorUnits: 0),
        outstanding: Money(minorUnits: 100),
        isClosed: false,
      ),
    };
  }

  @override
  Stream<Object?> watchOwnerChanges(String ownerId) => const Stream.empty();
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
