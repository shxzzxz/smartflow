import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_port_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';

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

  group('BusinessActivityReadModel', () {
    test('derives anchor identity and time from the loaded transaction', () {
      final occurredAt = DateTime(2026, 10, 12, 9, 30);
      final transaction = _transaction(
        id: 'tx-anchor',
        occurredAt: occurredAt,
        ownership: const TransactionOwnership(
          ownerType: 'orchestration.amortization',
          ownerId: 'plan-1',
        ),
      );
      final item = BusinessActivityReadModel.fromCandidate(
        candidate: BusinessActivityAnchorCandidate(
          activityKey: const BusinessActivityKey(
            type: 'orchestration.amortization',
            id: 'plan-1',
          ),
          anchorTransactionId: 'tx-anchor',
          anchorAt: occurredAt,
        ),
        anchorTransaction: transaction,
        summary: const LedgerBusinessActivitySummary(),
      );

      expect(item.anchorTransactionId, 'tx-anchor');
      expect(item.anchorAt, occurredAt);
      expect(item.ownerType, 'orchestration.amortization');
      expect(item.ownerId, 'plan-1');
    });

    test('rejects an anchor whose occurredAt differs from anchorAt', () {
      final transaction = _transaction(
        id: 'tx-anchor',
        occurredAt: DateTime(2026, 10, 12),
      );

      expect(
        () => BusinessActivityReadModel.fromCandidate(
          candidate: BusinessActivityAnchorCandidate(
            activityKey: const BusinessActivityKey.transactionGroup(
              'tx-anchor',
            ),
            anchorTransactionId: 'tx-anchor',
            anchorAt: DateTime(2026, 10, 13),
          ),
          anchorTransaction: transaction,
          summary: const LedgerBusinessActivitySummary(),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a child transaction as an item anchor', () {
      final occurredAt = DateTime(2026, 10, 12);
      final transaction = _transaction(
        id: 'tx-child',
        occurredAt: occurredAt,
        parentTransactionId: 'tx-parent',
      );

      expect(
        () => BusinessActivityReadModel.fromCandidate(
          candidate: BusinessActivityAnchorCandidate(
            activityKey: const BusinessActivityKey.transactionGroup(
              'tx-parent',
            ),
            anchorTransactionId: 'tx-child',
            anchorAt: occurredAt,
          ),
          anchorTransaction: transaction,
          summary: const LedgerBusinessActivitySummary(),
        ),
        throwsArgumentError,
      );
    });
  });

  test(
    'BusinessActivityPage returns a cursor only when another page exists',
    () {
      final occurredAt = DateTime(2026, 10, 12);
      final item = BusinessActivityReadModel.fromCandidate(
        candidate: BusinessActivityAnchorCandidate(
          activityKey: const BusinessActivityKey.transactionGroup('tx-1'),
          anchorTransactionId: 'tx-1',
          anchorAt: occurredAt,
        ),
        anchorTransaction: _transaction(id: 'tx-1', occurredAt: occurredAt),
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

final class _Source implements BusinessActivitySource {
  _Source(this.sourceKey, this.supportedActivityTypes);

  @override
  final String sourceKey;

  @override
  final Set<String> supportedActivityTypes;

  var findCalls = 0;

  @override
  Future<BusinessActivitySourcePage> findAnchorPage(
    BusinessActivityPageQuery query,
  ) async {
    findCalls += 1;
    return BusinessActivitySourcePage(anchors: const [], hasMore: false);
  }

  @override
  Stream<BusinessActivitySourcePage> watchAnchorPage(
    BusinessActivityPageQuery query,
  ) {
    return const Stream.empty();
  }

  @override
  Future<Map<BusinessActivityKey, BusinessActivitySummary>> findSummaries(
    Iterable<BusinessActivityAnchorCandidate> anchors,
  ) async {
    return const {};
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
