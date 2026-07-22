import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/ledger/ledger_query_port_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/time/month_key.dart';

void main() {
  test('reimbursement outstanding includes refunds', () async {
    final parent = _transaction(
      id: 'parent',
      purpose: BusinessPurpose.reimbursementAdvance,
      amount: 10000,
    );
    final refund = _transaction(
      id: 'refund',
      parentId: 'parent',
      purpose: BusinessPurpose.refund,
      amount: 2000,
    );
    final receipt = _transaction(
      id: 'receipt',
      parentId: 'parent',
      purpose: BusinessPurpose.reimbursementReceipt,
      amount: 6000,
    );
    final service = TransactionQueryServiceImpl(
      transactionRead: _FakeTransactionReadRepository(
        transactions: {'parent': parent, 'refund': refund, 'receipt': receipt},
        reimbursementAggregate: const {
          BusinessPurpose.refund: TransactionChildAggregate(
            sumMinor: 2000,
            count: 1,
          ),
          BusinessPurpose.reimbursementReceipt: TransactionChildAggregate(
            sumMinor: 6000,
            count: 1,
          ),
        },
      ),
      entryRead: const _FakeEntryReadRepository(),
      detailRead: const _FakeTransactionDetailReadRepository(),
      metricsSource: const _UnusedLedgerMetricsSource(),
    );

    final detail = await service.findTransactionDetail('parent');

    expect(detail, isNotNull);
    expect(
      detail!.reimbursementSummary?.outstanding,
      const Money(minorUnits: 2000),
    );
    expect(detail.refundedTotal, const Money(minorUnits: 2000));
  });

  test(
    'reimbursement advance list item aggregates refunds and receipts separately',
    () async {
      final parent = _transaction(
        id: 'parent',
        purpose: BusinessPurpose.reimbursementAdvance,
        amount: 10000,
      );
      final refund = _transaction(
        id: 'refund',
        parentId: 'parent',
        purpose: BusinessPurpose.refund,
        amount: 2000,
      );
      final receipt = _transaction(
        id: 'receipt',
        parentId: 'parent',
        purpose: BusinessPurpose.reimbursementReceipt,
        amount: 4000,
      );
      final service = TransactionQueryServiceImpl(
        transactionRead: _FakeTransactionReadRepository(
          transactions: {
            'parent': parent,
            'refund': refund,
            'receipt': receipt,
          },
          reimbursementAggregate: const {
            BusinessPurpose.refund: TransactionChildAggregate(
              sumMinor: 2000,
              count: 1,
            ),
            BusinessPurpose.reimbursementReceipt: TransactionChildAggregate(
              sumMinor: 4000,
              count: 1,
            ),
          },
        ),
        entryRead: const _FakeEntryReadRepository(),
        detailRead: const _FakeTransactionDetailReadRepository(),
        metricsSource: const _UnusedLedgerMetricsSource(),
      );

      final item =
          (await service.watchTransactions(const TransactionListQuery()).first)
              .single;

      expect(item.refundedTotal, const Money(minorUnits: 2000));
      expect(item.refundChildCount, 1);
      expect(item.reimbursementReceivedTotal, const Money(minorUnits: 4000));
      expect(item.reimbursementChildCount, 1);
    },
  );

  test('child detail includes parent reimbursement closed summary', () async {
    final parent = _transaction(
      id: 'parent',
      purpose: BusinessPurpose.reimbursementAdvance,
      amount: 10000,
    );
    final receipt = _transaction(
      id: 'receipt',
      parentId: 'parent',
      purpose: BusinessPurpose.reimbursementReceipt,
      amount: 4000,
    );
    final service = TransactionQueryServiceImpl(
      transactionRead: _FakeTransactionReadRepository(
        transactions: {'parent': parent, 'receipt': receipt},
        reimbursementAggregate: const {
          BusinessPurpose.reimbursementReceipt: TransactionChildAggregate(
            sumMinor: 4000,
            count: 1,
          ),
          BusinessPurpose.reimbursementClose: TransactionChildAggregate(
            sumMinor: 6000,
            count: 1,
          ),
        },
      ),
      entryRead: const _FakeEntryReadRepository(),
      detailRead: const _FakeTransactionDetailReadRepository(),
      metricsSource: const _UnusedLedgerMetricsSource(),
    );

    final detail = await service.findTransactionDetail('receipt');

    expect(detail, isNotNull);
    expect(detail!.reimbursementSummary?.isClosed, isTrue);
    expect(
      detail.reimbursementSummary?.receivedAmount,
      const Money(minorUnits: 10000),
    );
    expect(detail.reimbursementSummary?.outstanding, Money.zero());
  });
}

Transaction _transaction({
  required String id,
  required BusinessPurpose purpose,
  required int amount,
  String? parentId,
}) {
  return Transaction(
    id: id,
    parentTransactionId: parentId,
    businessPurpose: purpose,
    occurredAt: DateTime(2026, 7, 23),
    primaryAmount: Money(minorUnits: amount),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
    sourceKind: SourceKind.manual,
  );
}

class _FakeTransactionReadRepository implements TransactionReadRepository {
  const _FakeTransactionReadRepository({
    required this.transactions,
    required this.reimbursementAggregate,
  });

  final Map<String, Transaction> transactions;
  final Map<BusinessPurpose, TransactionChildAggregate> reimbursementAggregate;

  @override
  Future<Transaction?> findById(String id) async => transactions[id];

  @override
  Future<DateTime?> findCreatedAt(String id) async => null;

  @override
  Future<List<Transaction>> findByIds(Set<String> ids) async => [
    for (final id in ids)
      if (transactions[id] case final tx?) tx,
  ];

  @override
  Stream<List<Transaction>> watchPage(TransactionListQuery query) =>
      Stream.value([
        for (final transaction in transactions.values)
          if (!query.topLevelOnly || transaction.parentTransactionId == null)
            transaction,
      ]);

  @override
  Future<List<Transaction>> findChildren({required String parentId}) async =>
      transactions.values
          .where((transaction) => transaction.parentTransactionId == parentId)
          .toList();

  @override
  Future<Map<String, TransactionChildAggregate>> aggregateChildren({
    required Set<String> parentIds,
    required Set<BusinessPurpose> purposes,
  }) async {
    final result = <String, TransactionChildAggregate>{};
    for (final parentId in parentIds) {
      var sumMinor = 0;
      var count = 0;
      for (final transaction in transactions.values) {
        if (transaction.parentTransactionId == parentId &&
            purposes.contains(transaction.businessPurpose)) {
          sumMinor += transaction.primaryAmount.minorUnits;
          count += 1;
        }
      }
      if (count > 0) {
        result[parentId] = TransactionChildAggregate(
          sumMinor: sumMinor,
          count: count,
        );
      }
    }
    return result;
  }

  @override
  Future<Map<String, Map<TransactionDetailType, int>>>
  aggregateChildDetailAmounts({
    required Set<String> parentIds,
    required Set<TransactionDetailType> detailTypes,
  }) async => const {};

  @override
  Future<Map<String, Map<BusinessPurpose, TransactionChildAggregate>>>
  aggregateChildrenByPurpose({
    required Set<String> parentIds,
    required Set<BusinessPurpose> purposes,
  }) async {
    return {
      for (final parentId in parentIds)
        parentId: {
          for (final entry in reimbursementAggregate.entries)
            if (purposes.contains(entry.key)) entry.key: entry.value,
        },
    };
  }

  @override
  Stream<void> watchChanges() => const Stream.empty();
}

class _FakeEntryReadRepository implements EntryReadRepository {
  const _FakeEntryReadRepository();

  @override
  Future<Map<String, List<Entry>>> findByTransactionIds(
    Set<String> transactionIds,
  ) async => const {};
}

class _FakeTransactionDetailReadRepository
    implements TransactionDetailReadRepository {
  const _FakeTransactionDetailReadRepository();

  @override
  Future<Map<String, List<TransactionDetailRecord>>> findByTransactionIds(
    Set<String> transactionIds,
  ) async => const {};

  @override
  Future<Map<String, Map<TransactionDetailType, int>>> sumOwnByType({
    required Set<String> transactionIds,
    required Set<TransactionDetailType> detailTypes,
  }) async => const {};
}

class _UnusedLedgerMetricsSource implements LedgerMetricsSource {
  const _UnusedLedgerMetricsSource();

  @override
  Future<List<AccountAggregate>> aggregateByAccount({
    required Set<AccountType> accountTypes,
    required TransactionScopeFilter scope,
    DateTimeWindow window = const DateTimeWindow(),
  }) => throw UnimplementedError();

  @override
  Future<Map<AccountType, int>> aggregateByAccountType({
    required Set<AccountType> accountTypes,
    required TransactionScopeFilter scope,
    DateTimeWindow window = const DateTimeWindow(),
  }) => throw UnimplementedError();

  @override
  Future<Map<DateTime, Map<AccountType, int>>> aggregateByAccountTypeByDay({
    required Set<AccountType> accountTypes,
    required TransactionScopeFilter scope,
    DateTimeWindow window = const DateTimeWindow(),
  }) => throw UnimplementedError();

  @override
  Future<Map<MonthKey, Map<AccountType, int>>> aggregateByAccountTypeByMonth({
    required Set<AccountType> accountTypes,
    required TransactionScopeFilter scope,
    required DateTimeWindow window,
  }) => throw UnimplementedError();

  @override
  Stream<void> watchChanges() => const Stream.empty();
}
