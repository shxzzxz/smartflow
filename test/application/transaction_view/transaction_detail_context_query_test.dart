import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_detail/query/port/transaction_detail_owner_query.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';

class _MockTransactionQueryService extends Mock
    implements TransactionQueryService {}

class _OwnerQuery implements TransactionDetailOwnerQuery {
  _OwnerQuery({
    required this.ownerType,
    required this.summary,
    this.watchStream,
  });

  final String ownerType;
  TransactionDetailOwnerContext? summary;
  final Stream<TransactionDetailOwnerContext?>? watchStream;

  @override
  Set<String> get supportedOwnerTypes => {ownerType};

  @override
  Future<TransactionDetailOwnerContext?> find(
    TransactionOwnership ownership,
    TransactionReadModel anchorTransaction,
  ) async => summary;

  @override
  Stream<TransactionDetailOwnerContext?> watch(
    TransactionOwnership ownership,
    TransactionReadModel anchorTransaction,
  ) => watchStream ?? const Stream.empty();
}

void main() {
  late _MockTransactionQueryService transactions;

  setUp(() {
    transactions = _MockTransactionQueryService();
  });

  test('owns current and anchor groups through owner query seam', () async {
    final plan = AmortizationTransactionDetailOwnerContext(
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
      ownerQueries: [
        _OwnerQuery(
          ownerType: orchestrationAmortizationOwnerType,
          summary: plan,
        ),
      ],
    );

    final context = await query.findById('recognition');

    expect(context, isNotNull);
    expect(context!.transaction.id, 'recognition');
    expect(context.anchorTransaction.id, 'anchor');
    expect(context.owner, isA<AmortizationTransactionDetailOwnerContext>());
  });

  test('missing owner query is represented as unknown owner', () async {
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
      ownerQueries: const [],
    );

    final context = await query.findById('tx-1');

    expect(context, isNotNull);
    expect(context!.owner, isA<UnknownTransactionDetailOwnerContext>());
  });

  test('owner stream changes produce a new detail context', () async {
    final transaction = _transaction(
      id: 'advance-tx',
      purpose: BusinessPurpose.advance,
      ownerType: orchestrationAdvanceOwnerType,
    );
    final ledgerChanges = StreamController<TransactionReadModel?>();
    final ownerChanges = StreamController<TransactionDetailOwnerContext?>();
    addTearDown(ledgerChanges.close);
    addTearDown(ownerChanges.close);
    when(
      () => transactions.watchTransactionDetail('advance-tx'),
    ).thenAnswer((_) => ledgerChanges.stream);
    final initialOwner = _advanceOwner(outstanding: 8000, closed: false);
    final updatedOwner = _advanceOwner(outstanding: 5000, closed: false);
    final ownerQuery = _OwnerQuery(
      ownerType: orchestrationAdvanceOwnerType,
      summary: initialOwner,
      watchStream: ownerChanges.stream,
    );
    final query = TransactionDetailContextQueryImpl(
      transactions: transactions,
      ownerQueries: [ownerQuery],
    );
    final iterator = StreamIterator(query.watchById('advance-tx'));

    ledgerChanges.add(transaction);
    expect(await iterator.moveNext(), isTrue);
    expect(
      (iterator.current!.owner as AdvanceTransactionDetailOwnerContext)
          .outstanding,
      const Money(minorUnits: 8000),
    );

    ownerQuery.summary = updatedOwner;
    ownerChanges
      ..add(initialOwner)
      ..add(updatedOwner);
    expect(await iterator.moveNext(), isTrue);
    expect(
      (iterator.current!.owner as AdvanceTransactionDetailOwnerContext)
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

TransactionDetailOwnerContext _advanceOwner({
  required int outstanding,
  required bool closed,
}) {
  return AdvanceTransactionDetailOwnerContext(
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
