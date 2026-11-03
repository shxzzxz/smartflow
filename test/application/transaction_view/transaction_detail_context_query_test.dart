import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';

class _MockTransactionQueryService extends Mock
    implements TransactionQueryService {}

class _BusinessContextQuery implements TransactionBusinessContextQuery {
  _BusinessContextQuery({required this.summary, this.watchStream});

  TransactionBusinessContext? summary;
  final Stream<Map<String, TransactionBusinessContext>>? watchStream;

  @override
  Future<Map<String, TransactionBusinessContext>> findContexts(
    Iterable<TransactionReadModel> transactions,
  ) async => {for (final transaction in transactions) transaction.id: ?summary};

  @override
  Stream<Map<String, TransactionBusinessContext>> watchContexts(
    Iterable<TransactionReadModel> transactions,
  ) => watchStream ?? const Stream.empty();
}

void main() {
  late _MockTransactionQueryService transactions;

  setUp(() {
    transactions = _MockTransactionQueryService();
  });

  test(
    'owns current and anchor groups through business context seam',
    () async {
      final plan = AmortizationTransactionBusinessContext(
        ownerType: orchestrationAmortizationOwnerType,
        ownerId: 'plan-1',
        initialTransactionId: 'anchor',
        kind: AmortizationKind.prepaidExpense,
        status: AmortizationStatus.active,
        originalAmount: const Money(minorUnits: 12000),
        recognizedAmount: const Money(minorUnits: 2000),
        remainingAmount: const Money(minorUnits: 10000),
        postedPeriodCount: 1,
        totalPeriodCount: 3,
        categoryAccountIds: const ['insurance'],
      );
      final recognition = _transaction(
        id: 'recognition',
        purpose: BusinessPurpose.dailyExpense,
        ownerType: orchestrationAmortizationOwnerType,
      );
      final anchor = _transaction(
        id: 'anchor',
        purpose: BusinessPurpose.transfer,
        ownerType: orchestrationAmortizationOwnerType,
      );
      when(
        () => transactions.findTransactionDetail('recognition'),
      ).thenAnswer((_) async => recognition);
      when(
        () => transactions.findTransactionDetail('anchor'),
      ).thenAnswer((_) async => anchor);
      final query = TransactionDetailContextQueryImpl(
        transactions: transactions,
        businessContexts: _BusinessContextQuery(summary: plan),
      );

      final context = await query.findById('recognition');

      expect(context, isNotNull);
      expect(context!.transaction.id, 'recognition');
      expect(context.anchorTransaction.id, 'anchor');
      expect(
        context.businessContext,
        isA<AmortizationTransactionBusinessContext>(),
      );
      expect(context.categoryAccountIds, ['insurance']);
    },
  );

  test('missing business context is represented as unknown owner', () async {
    final transaction = _transaction(
      id: 'tx-1',
      purpose: BusinessPurpose.dailyExpense,
      ownerType: 'unknown.owner',
    );
    when(
      () => transactions.findTransactionDetail('tx-1'),
    ).thenAnswer((_) async => transaction);
    final query = TransactionDetailContextQueryImpl(
      transactions: transactions,
      businessContexts: TransactionBusinessContextQueryImpl(sources: const []),
    );

    final context = await query.findById('tx-1');

    expect(context, isNotNull);
    expect(
      context!.businessContext,
      isA<UnknownTransactionBusinessContext>(),
    );
  });

  test('business context changes produce a new detail context', () async {
    final transaction = _transaction(
      id: 'advance-tx',
      purpose: BusinessPurpose.advance,
      ownerType: orchestrationAdvanceOwnerType,
    );
    final ledgerChanges = StreamController<TransactionReadModel?>();
    final ownerChanges =
        StreamController<Map<String, TransactionBusinessContext>>();
    addTearDown(ledgerChanges.close);
    addTearDown(ownerChanges.close);
    when(
      () => transactions.watchTransactionDetail('advance-tx'),
    ).thenAnswer((_) => ledgerChanges.stream);
    final initialOwner = _advanceOwner(outstanding: 8000, closed: false);
    final updatedOwner = _advanceOwner(outstanding: 5000, closed: false);
    final ownerQuery = _BusinessContextQuery(
      summary: initialOwner,
      watchStream: ownerChanges.stream,
    );
    final query = TransactionDetailContextQueryImpl(
      transactions: transactions,
      businessContexts: ownerQuery,
    );
    final iterator = StreamIterator(query.watchById('advance-tx'));

    ledgerChanges.add(transaction);
    expect(await iterator.moveNext(), isTrue);
    expect(
      (iterator.current!.businessContext as AdvanceTransactionBusinessContext)
          .outstanding,
      const Money(minorUnits: 8000),
    );

    ownerQuery.summary = updatedOwner;
    ownerChanges
      ..add({'advance-tx': initialOwner})
      ..add({'advance-tx': updatedOwner});
    expect(await iterator.moveNext(), isTrue);
    expect(
      (iterator.current!.businessContext as AdvanceTransactionBusinessContext)
          .outstanding,
      const Money(minorUnits: 5000),
    );

    await iterator.cancel();
  });
}

TransactionReadModel _transaction({
  required String id,
  required BusinessPurpose purpose,
  String? ownerType,
}) {
  return TransactionReadModel(
    id: id,
    businessPurpose: purpose,
    occurredAt: DateTime(2026, 1),
    primaryAmount: const Money(minorUnits: 12000),
    ownership: ownerType == null
        ? null
        : TransactionOwnership(ownerType: ownerType, ownerId: 'owner-1'),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
  );
}

TransactionBusinessContext _advanceOwner({
  required int outstanding,
  required bool closed,
}) {
  return AdvanceTransactionBusinessContext(
    ownerType: orchestrationAdvanceOwnerType,
    ownerId: 'owner-1',
    scenario: AdvanceScenario.reimbursement,
    trackingMode: AdvanceTrackingMode.itemized,
    advanceAmount: const Money(minorUnits: 10000),
    receivedAmount: Money(minorUnits: 10000 - outstanding),
    outstanding: Money(minorUnits: outstanding),
    isClosed: closed,
  );
}
