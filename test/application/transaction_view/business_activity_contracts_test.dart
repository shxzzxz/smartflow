import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_port_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';

void main() {
  group('BusinessActivityPageQuery', () {
    test('freezes filter sets and carries the exclusive time window', () {
      final categories = {'food'};
      final settlements = {'cash'};
      final tags = {'travel'};
      final activityTypes = {ledgerTransactionGroupActivityType};
      final from = DateTime(2026, 10);
      final until = DateTime(2026, 11);

      final query = BusinessActivityPageQuery(
        occurredFrom: from,
        occurredUntil: until,
        activityTypes: activityTypes,
        categoryAccountIds: categories,
        settlementAccountIds: settlements,
        tagIds: tags,
        limit: 30,
      );

      categories.add('housing');
      settlements.add('credit');
      tags.add('work');
      activityTypes.add(installmentOwnerType);

      expect(query.occurredFrom, from);
      expect(query.occurredUntil, until);
      expect(query.activityTypes, {ledgerTransactionGroupActivityType});
      expect(query.categoryAccountIds, {'food'});
      expect(query.settlementAccountIds, {'cash'});
      expect(query.tagIds, {'travel'});
      expect(query.limit, 30);
    });

    test('requires a positive, ordered time window', () {
      expect(
        () => BusinessActivityPageQuery(
          occurredFrom: DateTime(2026, 11),
          occurredUntil: DateTime(2026, 11),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  test('query service skips sources with no requested item type', () async {
    final ledger = _Source('ledger', {ledgerTransactionGroupActivityType});
    final credit = _Source('credit', {installmentOwnerType});
    final service = BusinessActivityQueryServiceImpl(
      sources: [ledger, credit],
      transactionQuery: const _EmptyTransactionQuery(),
    );

    final page = await service.findPage(
      BusinessActivityPageQuery(
        occurredFrom: DateTime(2026, 10),
        occurredUntil: DateTime(2026, 11),
        activityTypes: const {ledgerTransactionGroupActivityType},
      ),
    );

    expect(page.items, isEmpty);
    expect(ledger.findCalls, 1);
    expect(credit.findCalls, 0);
  });

  test('query service deduplicates a repeated activity candidate', () async {
    final occurredAt = DateTime(2026, 10, 12);
    final transaction = _transaction(id: 'tx-1', occurredAt: occurredAt);
    const key = BusinessActivityKey.transactionGroup('tx-1');
    final candidate = BusinessActivityCandidate(
      activityKey: key,
      displayTransactionId: transaction.id,
      activityAt: occurredAt,
    );
    final source = _Source(
      'ledger',
      {ledgerTransactionGroupActivityType},
      candidates: [candidate, candidate],
      summaries: {key: const LedgerBusinessActivitySummary()},
    );
    final service = BusinessActivityQueryServiceImpl(
      sources: [source],
      transactionQuery: _StaticTransactionQuery([transaction]),
    );

    final page = await service.findPage(
      BusinessActivityPageQuery(
        occurredFrom: DateTime(2026, 10),
        occurredUntil: DateTime(2026, 11),
      ),
    );

    expect(page.items, hasLength(1));
    expect(page.items.single.activityKey, key);
    expect(source.summaryAnchorCounts, [1]);
  });

  test(
    'lookup builds one activity from its key and display projection',
    () async {
      final occurredAt = DateTime(2026, 10, 12);
      final transaction = _transaction(id: 'tx-1', occurredAt: occurredAt);
      final key = const BusinessActivityKey.transactionGroup('tx-1');
      final source = _Source(
        'ledger',
        {ledgerTransactionGroupActivityType},
        summaries: {key: const LedgerBusinessActivitySummary()},
      );
      final service = BusinessActivityQueryServiceImpl(
        sources: [source],
        transactionQuery: const _EmptyTransactionQuery(),
      );

      final activity = await service.findForActivity(
        activityKey: key,
        activityAt: occurredAt,
        displayTransaction: transaction,
      );

      expect(activity, isNotNull);
      expect(activity!.displayTransaction, same(transaction));
      expect(activity.summary, isA<LedgerBusinessActivitySummary>());
    },
  );

  group('BusinessActivityReadModel', () {
    test(
      'keeps business identity and time independent from its projection',
      () {
        final transactionOccurredAt = DateTime(2026, 10, 12, 9, 30);
        final activityAt = DateTime(2026, 10, 20, 18);
        final transaction = _transaction(
          id: 'tx-display',
          occurredAt: transactionOccurredAt,
          ownership: const TransactionOwnership(
            ownerType: 'orchestration.amortization',
            ownerId: 'plan-1',
          ),
        );
        final item = BusinessActivityReadModel.fromCandidate(
          candidate: BusinessActivityCandidate(
            activityKey: const BusinessActivityKey(
              type: 'orchestration.amortization',
              id: 'plan-1',
            ),
            displayTransactionId: 'tx-display',
            activityAt: activityAt,
          ),
          displayTransaction: transaction,
          summary: const LedgerBusinessActivitySummary(),
        );

        expect(item.displayTransactionId, 'tx-display');
        expect(item.activityAt, activityAt);
        expect(
          item.activityKey,
          const BusinessActivityKey(
            type: 'orchestration.amortization',
            id: 'plan-1',
          ),
        );
      },
    );

    test('does not require an activity key to match transaction ownership', () {
      final transaction = _transaction(
        id: 'tx-display',
        occurredAt: DateTime(2026, 10, 12),
        ownership: const TransactionOwnership(
          ownerType: 'orchestration.advance',
          ownerId: 'advance-1',
        ),
      );

      final item = BusinessActivityReadModel.fromCandidate(
        candidate: BusinessActivityCandidate(
          activityKey: const BusinessActivityKey(
            type: 'credit.installment_contract',
            id: 'contract-1',
          ),
          displayTransactionId: 'tx-display',
          activityAt: DateTime(2026, 10, 20),
        ),
        displayTransaction: transaction,
        summary: const LedgerBusinessActivitySummary(),
      );

      expect(item.activityKey.id, 'contract-1');
      expect(item.displayTransaction, same(transaction));
    });

    test('builds an activity without a display transaction', () {
      const key = BusinessActivityKey(
        type: 'credit.repayment',
        id: 'repayment-1',
      );
      final activityAt = DateTime(2026, 10, 12);

      final item = BusinessActivityReadModel.fromCandidate(
        candidate: BusinessActivityCandidate(
          activityKey: key,
          activityAt: activityAt,
        ),
        summary: const LedgerBusinessActivitySummary(),
      );

      expect(item.activityKey, key);
      expect(item.activityAt, activityAt);
      expect(item.displayTransaction, isNull);
      expect(item.displayTransactionId, isNull);
    });
  });

  test(
    'query service merges transactionless activities without loading transactions',
    () async {
      const ledgerKey = BusinessActivityKey.transactionGroup('ledger-1');
      const repaymentKey = BusinessActivityKey(
        type: creditRepaymentOwnerType,
        id: 'repayment-1',
      );
      final ledger = _Source(
        'ledger',
        {ledgerTransactionGroupActivityType},
        candidates: [
          BusinessActivityCandidate(
            activityKey: ledgerKey,
            activityAt: DateTime(2026, 10, 2),
          ),
        ],
        summaries: {ledgerKey: const LedgerBusinessActivitySummary()},
      );
      final repayment = _Source(
        'credit',
        {creditRepaymentOwnerType},
        candidates: [
          BusinessActivityCandidate(
            activityKey: repaymentKey,
            activityAt: DateTime(2026, 10, 3),
          ),
        ],
        summaries: {
          repaymentKey: const RepaymentBusinessActivitySummary(
            repaymentType: RepaymentType.bill,
            targetType: RepaymentTargetType.bill,
          ),
        },
      );
      final service = BusinessActivityQueryServiceImpl(
        sources: [ledger, repayment],
        transactionQuery: const _ExplodingTransactionQuery(),
      );

      final page = await service.findPage(
        BusinessActivityPageQuery(
          occurredFrom: DateTime(2026, 10),
          occurredUntil: DateTime(2026, 11),
        ),
      );

      expect(page.items.map((item) => item.activityKey), [
        repaymentKey,
        ledgerKey,
      ]);
      expect(
        page.items.every((item) => item.displayTransaction == null),
        isTrue,
      );
    },
  );

  test(
    'watchContents refreshes summaries for the current members only',
    () async {
      final transaction = _transaction(
        id: 'advance-anchor',
        occurredAt: DateTime(2026, 10, 2),
        ownership: const TransactionOwnership(
          ownerType: orchestrationAdvanceOwnerType,
          ownerId: 'advance-1',
        ),
      );
      final source = _WatchingSource();
      final service = BusinessActivityQueryServiceImpl(
        sources: [source],
        transactionQuery: _StaticTransactionQuery([transaction]),
      );
      final initial = await service.findForActivity(
        activityKey: const BusinessActivityKey(
          type: orchestrationAdvanceOwnerType,
          id: 'advance-1',
        ),
        activityAt: transaction.occurredAt,
        displayTransaction: transaction,
      );
      final events = <Map<BusinessActivityKey, BusinessActivityReadModel>>[];
      final subscription = service.watchContents([initial!]).listen(events.add);
      addTearDown(subscription.cancel);
      addTearDown(source._controller.close);

      await pumpEventQueue();
      expect(
        (events.last.values.single.summary as AdvanceBusinessActivitySummary)
            .outstanding,
        const Money(minorUnits: 900),
      );

      source.emit(
        const BusinessActivityKey(
          type: orchestrationAdvanceOwnerType,
          id: 'advance-1',
        ),
        AdvanceBusinessActivitySummary(
          scenario: AdvanceScenario.reimbursement,
          trackingMode: AdvanceTrackingMode.itemized,
          outstanding: const Money(minorUnits: 700),
          isClosed: false,
        ),
      );
      await pumpEventQueue();

      expect(events, hasLength(2));
      expect(
        (events.last.values.single.summary as AdvanceBusinessActivitySummary)
            .outstanding,
        const Money(minorUnits: 700),
      );
    },
  );

  test(
    'watchContents refreshes a transactionless activity without transaction IO',
    () async {
      const key = BusinessActivityKey(
        type: orchestrationAdvanceOwnerType,
        id: 'advance-1',
      );
      final source = _WatchingSource();
      final service = BusinessActivityQueryServiceImpl(
        sources: [source],
        transactionQuery: const _ExplodingTransactionQuery(),
      );
      final initial = BusinessActivityReadModel.fromCandidate(
        candidate: BusinessActivityCandidate(
          activityKey: key,
          activityAt: DateTime(2026, 10, 2),
        ),
        summary: source._summary,
      );
      final events = <Map<BusinessActivityKey, BusinessActivityReadModel>>[];
      final subscription = service.watchContents([initial]).listen(events.add);
      addTearDown(subscription.cancel);
      addTearDown(source._controller.close);

      await pumpEventQueue();
      expect(events.last.values.single.displayTransaction, isNull);
      expect(
        (events.last.values.single.summary as AdvanceBusinessActivitySummary)
            .outstanding,
        const Money(minorUnits: 900),
      );

      source.emit(
        key,
        AdvanceBusinessActivitySummary(
          scenario: AdvanceScenario.reimbursement,
          trackingMode: AdvanceTrackingMode.itemized,
          outstanding: const Money(minorUnits: 700),
          isClosed: false,
        ),
      );
      await pumpEventQueue();

      expect(events, hasLength(2));
      expect(events.last.values.single.displayTransaction, isNull);
      expect(
        (events.last.values.single.summary as AdvanceBusinessActivitySummary)
            .outstanding,
        const Money(minorUnits: 700),
      );
    },
  );

  test(
    'BusinessActivityPage returns a cursor only when another page exists',
    () {
      final occurredAt = DateTime(2026, 10, 12);
      final item = BusinessActivityReadModel.fromCandidate(
        candidate: BusinessActivityCandidate(
          activityKey: const BusinessActivityKey.transactionGroup('tx-1'),
          displayTransactionId: 'tx-1',
          activityAt: occurredAt,
        ),
        displayTransaction: _transaction(id: 'tx-1', occurredAt: occurredAt),
        summary: const LedgerBusinessActivitySummary(),
      );

      expect(
        BusinessActivityPage(items: [item], hasMore: false).nextCursor,
        isNull,
      );
      expect(
        BusinessActivityPage(
          items: [item],
          hasMore: true,
        ).nextCursor?.activityKey,
        const BusinessActivityKey.transactionGroup('tx-1'),
      );
    },
  );
}

final class _WatchingSource implements BusinessActivitySource {
  _WatchingSource()
    : _summary = AdvanceBusinessActivitySummary(
        scenario: AdvanceScenario.reimbursement,
        trackingMode: AdvanceTrackingMode.itemized,
        outstanding: const Money(minorUnits: 900),
        isClosed: false,
      );

  final _controller =
      StreamController<
        Map<BusinessActivityKey, BusinessActivitySummary>
      >.broadcast();
  BusinessActivitySummary _summary;
  final _key = const BusinessActivityKey(
    type: orchestrationAdvanceOwnerType,
    id: 'advance-1',
  );

  @override
  String get sourceKey => 'advance';

  @override
  Set<String> get supportedActivityTypes => const {
    orchestrationAdvanceOwnerType,
  };

  @override
  Future<BusinessActivitySourcePage> findCandidatePage(
    BusinessActivityPageQuery query,
  ) async => BusinessActivitySourcePage(candidates: const [], hasMore: false);

  @override
  Stream<BusinessActivitySourcePage> watchCandidatePage(
    BusinessActivityPageQuery query,
  ) => const Stream.empty();

  @override
  Future<Map<BusinessActivityKey, BusinessActivitySummary>> findSummaries(
    Iterable<BusinessActivityCandidate> anchors,
  ) async => {_key: _summary};

  @override
  Stream<Map<BusinessActivityKey, BusinessActivitySummary>> watchSummaries(
    Iterable<BusinessActivityCandidate> anchors,
  ) async* {
    yield {_key: _summary};
    yield* _controller.stream;
  }

  void emit(BusinessActivityKey key, BusinessActivitySummary summary) {
    _summary = summary;
    _controller.add({key: summary});
  }
}

final class _Source implements BusinessActivitySource {
  _Source(
    this.sourceKey,
    this.supportedActivityTypes, {
    this.candidates = const [],
    this.summaries = const {},
  });

  @override
  final String sourceKey;

  @override
  final Set<String> supportedActivityTypes;
  final List<BusinessActivityCandidate> candidates;
  final Map<BusinessActivityKey, BusinessActivitySummary> summaries;

  var findCalls = 0;
  final summaryAnchorCounts = <int>[];

  @override
  Future<BusinessActivitySourcePage> findCandidatePage(
    BusinessActivityPageQuery query,
  ) async {
    findCalls += 1;
    return BusinessActivitySourcePage(candidates: candidates, hasMore: false);
  }

  @override
  Stream<BusinessActivitySourcePage> watchCandidatePage(
    BusinessActivityPageQuery query,
  ) {
    return const Stream.empty();
  }

  @override
  Future<Map<BusinessActivityKey, BusinessActivitySummary>> findSummaries(
    Iterable<BusinessActivityCandidate> anchors,
  ) async {
    summaryAnchorCounts.add(anchors.length);
    return summaries;
  }

  @override
  Stream<Map<BusinessActivityKey, BusinessActivitySummary>> watchSummaries(
    Iterable<BusinessActivityCandidate> anchors,
  ) {
    return Stream.fromFuture(findSummaries(anchors));
  }
}

final class _EmptyTransactionQuery implements TransactionBatchQueryService {
  const _EmptyTransactionQuery();

  @override
  Future<List<TransactionReadModel>> findTransactionsByIds(
    Set<String> ids,
  ) async {
    return const [];
  }

  @override
  Stream<List<TransactionReadModel>> watchTransactionsByIds(Set<String> ids) {
    return Stream.fromFuture(findTransactionsByIds(ids));
  }
}

final class _ExplodingTransactionQuery implements TransactionBatchQueryService {
  const _ExplodingTransactionQuery();

  @override
  Future<List<TransactionReadModel>> findTransactionsByIds(Set<String> ids) {
    throw StateError('Transactionless activities must not query transactions.');
  }

  @override
  Stream<List<TransactionReadModel>> watchTransactionsByIds(Set<String> ids) {
    throw StateError('Transactionless activities must not watch transactions.');
  }
}

final class _StaticTransactionQuery implements TransactionBatchQueryService {
  const _StaticTransactionQuery(this.transactions);

  final List<TransactionReadModel> transactions;

  @override
  Future<List<TransactionReadModel>> findTransactionsByIds(
    Set<String> ids,
  ) async {
    return [
      for (final transaction in transactions)
        if (ids.contains(transaction.id)) transaction,
    ];
  }

  @override
  Stream<List<TransactionReadModel>> watchTransactionsByIds(Set<String> ids) {
    return Stream.fromFuture(findTransactionsByIds(ids));
  }
}

TransactionReadModel _transaction({
  required String id,
  required DateTime occurredAt,
  String? parentTransactionId,
  TransactionOwnership? ownership,
}) {
  return TransactionReadModel(
    id: id,
    parentTransactionId: parentTransactionId,
    businessPurpose: BusinessPurpose.dailyExpense,
    occurredAt: occurredAt,
    primaryAmount: Money(minorUnits: 100),
    ownership: ownership,
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
  );
}
