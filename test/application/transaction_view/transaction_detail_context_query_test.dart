import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';

class _MockTransactionQueryService extends Mock
    implements TransactionQueryService {}

class _MockBusinessActivityQueryService extends Mock
    implements BusinessActivityQueryService {}

class _ItemQuery implements BusinessActivityItemQuery {
  _ItemQuery({required this.items});

  final Map<String, BusinessActivityItem> items;
  var calls = 0;

  @override
  Future<Map<String, BusinessActivityItem>> findItems(
    Iterable<TransactionReadModel> transactions,
  ) async {
    calls += 1;
    return {
      for (final transaction in transactions)
        transaction.id: ?items[transaction.id],
    };
  }

  @override
  Stream<Map<String, BusinessActivityItem>> watchItems(
    Iterable<TransactionReadModel> transactions,
  ) => const Stream.empty();
}

void main() {
  late _MockTransactionQueryService transactions;
  late _MockBusinessActivityQueryService activities;

  setUp(() {
    transactions = _MockTransactionQueryService();
    activities = _MockBusinessActivityQueryService();
  });

  test('local context loads only the current transaction item', () async {
    final transaction = _transaction(
      id: 'refund',
      purpose: BusinessPurpose.transfer,
      ownerType: orchestrationAmortizationOwnerType,
    );
    final item = _amortizationItem(
      transaction.id,
      factKind: AmortizationTransactionFactKind.refund,
    );
    final itemQuery = _ItemQuery(items: {transaction.id: item});
    when(
      () => transactions.findTransactionDetail('refund'),
    ).thenAnswer((_) async => transaction);
    final query = TransactionDetailContextQueryImpl(
      transactions: transactions,
      businessItems: itemQuery,
    );

    final context = await query.findById('refund');

    expect(context, isNotNull);
    expect(context!.businessItem, same(item));
    expect(context.businessItem!.itemKey, item.itemKey);
    expect(context.businessItem!.role, item.role);
    expect(context.transactionProjection, same(item.projections.single));
    expect(context.transactionProjection!.transactionId, 'refund');
    expect(context.isAmortizationTerminated, isFalse);
    expect(itemQuery.calls, 1);
  });

  test('higher-level detail loads activity only for an entry item', () async {
    final transaction = _transaction(
      id: 'initial',
      purpose: BusinessPurpose.transfer,
      ownerType: orchestrationAmortizationOwnerType,
    );
    final item = _amortizationItem(
      transaction.id,
      factKind: AmortizationTransactionFactKind.initial,
    );
    final activity = _activity(transaction);
    when(
      () => transactions.findTransactionDetail('initial'),
    ).thenAnswer((_) async => transaction);
    when(
      () => activities.findForAnchor(
        activityKey: item.activityKey,
        anchorTransaction: transaction,
      ),
    ).thenAnswer((_) async => activity);
    final local = TransactionDetailContextQueryImpl(
      transactions: transactions,
      businessItems: _ItemQuery(items: {transaction.id: item}),
    );
    final query = TransactionDetailQueryImpl(
      localContext: local,
      businessActivities: activities,
    );

    final detail = await query.findById('initial');

    expect(detail, isNotNull);
    expect(detail!.businessActivity, same(activity));
    verify(
      () => activities.findForAnchor(
        activityKey: item.activityKey,
        anchorTransaction: transaction,
      ),
    ).called(1);
  });

  test('higher-level detail skips activity for a non-entry item', () async {
    final transaction = _transaction(
      id: 'refund',
      purpose: BusinessPurpose.transfer,
      ownerType: orchestrationAmortizationOwnerType,
    );
    final item = _amortizationItem(
      transaction.id,
      factKind: AmortizationTransactionFactKind.refund,
    );
    when(
      () => transactions.findTransactionDetail('refund'),
    ).thenAnswer((_) async => transaction);
    final local = TransactionDetailContextQueryImpl(
      transactions: transactions,
      businessItems: _ItemQuery(items: {transaction.id: item}),
    );
    final query = TransactionDetailQueryImpl(
      localContext: local,
      businessActivities: activities,
    );

    final detail = await query.findById('refund');

    expect(detail!.businessActivity, isNull);
    verifyNever(
      () => activities.findForAnchor(
        activityKey: item.activityKey,
        anchorTransaction: transaction,
      ),
    );
  });

  test('advance child loads only bounded parent facts', () async {
    final transaction = _transaction(
      id: 'collection',
      purpose: BusinessPurpose.advanceCollection,
      ownerType: orchestrationAdvanceOwnerType,
      parentTransactionId: 'advance',
    );
    when(
      () => transactions.findTransactionDetail('collection'),
    ).thenAnswer((_) async => transaction);
    when(() => transactions.findTransactionById('advance')).thenAnswer(
      (_) async => Transaction(
        id: 'advance',
        businessPurpose: BusinessPurpose.advance,
        occurredAt: DateTime(2026, 1),
        primaryAmount: const Money(minorUnits: 12000),
        isExcludedFromStats: true,
        isExcludedFromBudget: false,
        sourceKind: SourceKind.manual,
      ),
    );
    when(
      () => transactions.hasChildTransaction(
        parentTransactionId: 'advance',
        businessPurpose: BusinessPurpose.advanceSettlement,
      ),
    ).thenAnswer((_) async => true);
    final query = TransactionDetailContextQueryImpl(
      transactions: transactions,
      businessItems: _ItemQuery(items: const {}),
    );

    final context = await query.findById('collection');

    expect(context!.parentFacts!.isExcludedFromStats, isTrue);
    expect(context.parentFacts!.isExcludedFromBudget, isFalse);
    expect(context.parentFacts!.isAdvanceClosed, isTrue);
    verifyNever(() => transactions.findParentTransactionDetail('advance'));
  });

  test(
    'missing item is represented as unknown without hiding transaction',
    () async {
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
        businessItems: BusinessActivityItemQueryImpl(sources: const []),
      );

      final context = await query.findById('tx-1');

      expect(context, isNotNull);
      expect(context!.businessItem, isA<UnknownBusinessActivityItem>());
    },
  );
}

TransactionReadModel _transaction({
  required String id,
  required BusinessPurpose purpose,
  String? ownerType,
  String? parentTransactionId,
}) {
  return TransactionReadModel(
    id: id,
    parentTransactionId: parentTransactionId,
    businessPurpose: purpose,
    occurredAt: DateTime(2026, 1),
    primaryAmount: const Money(minorUnits: 12000),
    ownership: ownerType == null
        ? null
        : TransactionOwnership(ownerType: ownerType, ownerId: 'plan-1'),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
  );
}

AmortizationBusinessActivityItem _amortizationItem(
  String transactionId, {
  required AmortizationTransactionFactKind factKind,
}) {
  return AmortizationBusinessActivityItem(
    activityKey: const BusinessActivityKey(
      type: orchestrationAmortizationOwnerType,
      id: 'plan-1',
    ),
    itemKey: BusinessActivityItemKey.transaction(transactionId),
    role: factKind == AmortizationTransactionFactKind.initial
        ? BusinessActivityItemRole.origin
        : BusinessActivityItemRole.followUp,
    occurredAt: DateTime(2026, 1),
    projections: [
      AmortizationTransactionProjection(
        transactionId: transactionId,
        localCategoryAllocations: const [
          AccountAmountAllocation(
            accountId: 'food',
            amount: Money(minorUnits: 100),
          ),
        ],
      ),
    ],
    kind: AmortizationKind.prepaidExpense,
    factKind: factKind,
  );
}

BusinessActivityReadModel _activity(TransactionReadModel transaction) {
  return BusinessActivityReadModel.fromCandidate(
    candidate: BusinessActivityAnchorCandidate(
      activityKey: const BusinessActivityKey(
        type: orchestrationAmortizationOwnerType,
        id: 'plan-1',
      ),
      anchorTransactionId: transaction.id,
      anchorAt: transaction.occurredAt,
    ),
    anchorTransaction: transaction,
    summary: AmortizationBusinessActivitySummary(
      kind: AmortizationKind.prepaidExpense,
      status: AmortizationStatus.active,
      originalAmount: Money(minorUnits: 12000),
      recognizedAmount: const Money(minorUnits: 0),
      remainingAmount: Money(minorUnits: 12000),
      postedPeriodCount: 0,
      totalPeriodCount: 3,
      categoryAccountIds: ['food'],
    ),
  );
}
