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
    final service = _service(
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
    'reimbursement advance list item carries refund and receipt adjustments',
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
      final service = _service(
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
      );

      final item =
          (await service.watchTransactions(const TransactionListQuery()).first)
              .single;

      expect(item.adjustments.map((adjustment) => adjustment.kind), [
        TransactionAdjustmentKind.refund,
        TransactionAdjustmentKind.reimbursementReceived,
      ]);
      expect(item.adjustments.first.amount, const Money(minorUnits: 2000));
      expect(item.adjustments.last.amount, const Money(minorUnits: 4000));
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
    final service = _service(
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

  test(
    'projects category and settlement refs from account snapshots',
    () async {
      final expense = _transaction(
        id: 'expense',
        purpose: BusinessPurpose.dailyExpense,
        amount: 1000,
      );
      final transactionRead = _FakeTransactionReadRepository(
        transactions: {'expense': expense},
      );
      final service = _service(
        transactionRead: transactionRead,
        entryRead: _FakeEntryReadRepository({
          'expense': [
            _entry('e1', 'expense', 'dining', EntryDirection.debit, 1000),
            _entry('e2', 'expense', 'cash', EntryDirection.credit, 1000),
          ],
        }),
        accounts: [
          _account('dining', AccountType.expense, name: '餐饮', iconKey: 'bowl'),
          _account('cash', AccountType.asset, name: '现金'),
        ],
      );

      final item =
          (await service.watchTransactions(const TransactionListQuery()).first)
              .single;

      expect(item.category?.id, 'dining');
      expect(item.category?.name, '餐饮');
      expect(item.category?.iconKey, 'bowl');
      expect(item.settlementEntries.single.accountId, 'cash');
      expect(item.settlementEntries.single.accountName, '现金');
      expect(item.settlementEntries.single.direction, EntryDirection.credit);
      expect(
        item.settlementEntries.single.amount,
        const Money(minorUnits: 1000),
      );
    },
  );

  test('expands a first-level category into itself and its children', () async {
    final transactionRead = _FakeTransactionReadRepository(transactions: {});
    final service = _service(
      transactionRead: transactionRead,
      accounts: [
        _account('food', AccountType.expense),
        _account('dining', AccountType.expense, parentId: 'food'),
        _account('hotpot', AccountType.expense, parentId: 'food'),
        _account('travel', AccountType.expense),
      ],
    );

    await service.findTransactions(
      const TransactionListQuery(categoryId: 'food'),
    );

    expect(transactionRead.lastPageQuery?.categoryAccountIds, {
      'food',
      'dining',
      'hotpot',
    });
  });

  test('expands a second-level category into itself only', () async {
    final transactionRead = _FakeTransactionReadRepository(transactions: {});
    final service = _service(
      transactionRead: transactionRead,
      accounts: [
        _account('food', AccountType.expense),
        _account('dining', AccountType.expense, parentId: 'food'),
      ],
    );

    await service.findTransactions(
      const TransactionListQuery(categoryId: 'dining'),
    );

    expect(transactionRead.lastPageQuery?.categoryAccountIds, {'dining'});
  });

  test('categoryOwnOnly keeps the first-level category unexpanded', () async {
    final transactionRead = _FakeTransactionReadRepository(transactions: {});
    final service = _service(
      transactionRead: transactionRead,
      accounts: [
        _account('food', AccountType.expense),
        _account('dining', AccountType.expense, parentId: 'food'),
      ],
    );

    await service.findTransactions(
      const TransactionListQuery(categoryId: 'food', categoryOwnOnly: true),
    );

    expect(transactionRead.lastPageQuery?.categoryAccountIds, {'food'});
  });

  test(
    'returns empty list when the filtered category no longer exists',
    () async {
      final transactionRead = _FakeTransactionReadRepository(
        transactions: {
          'expense': _transaction(
            id: 'expense',
            purpose: BusinessPurpose.dailyExpense,
            amount: 1000,
          ),
        },
      );
      final service = _service(transactionRead: transactionRead);

      final items = await service.findTransactions(
        const TransactionListQuery(categoryId: 'missing'),
      );

      expect(items, isEmpty);
      expect(transactionRead.lastPageQuery, isNull);
    },
  );

  test('passes the settlement account filter through unchanged', () async {
    final transactionRead = _FakeTransactionReadRepository(transactions: {});
    final service = _service(transactionRead: transactionRead);

    await service.findTransactions(
      const TransactionListQuery(settlementAccountId: 'cash'),
    );

    expect(transactionRead.lastPageQuery?.settlementAccountIds, {'cash'});
    expect(transactionRead.lastPageQuery?.categoryAccountIds, isNull);
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

Entry _entry(
  String id,
  String transactionId,
  String accountId,
  EntryDirection direction,
  int amountMinor,
) {
  return Entry(
    id: id,
    transactionId: transactionId,
    accountId: accountId,
    direction: direction,
    amount: Money(minorUnits: amountMinor),
  );
}

Account _account(
  String id,
  AccountType type, {
  String? name,
  String? parentId,
  String? iconKey,
}) {
  return Account(
    id: id,
    name: name ?? id,
    type: type,
    parentId: parentId,
    iconKey: iconKey,
    balance: const Money(minorUnits: 0),
  );
}

TransactionQueryServiceImpl _service({
  required _FakeTransactionReadRepository transactionRead,
  _FakeEntryReadRepository entryRead = const _FakeEntryReadRepository({}),
  List<Account> accounts = const [],
}) {
  return TransactionQueryServiceImpl(
    transactionRead: transactionRead,
    entryRead: entryRead,
    detailRead: const _FakeTransactionDetailReadRepository(),
    accountQuery: _FakeAccountQueryService(accounts),
    metricsSource: const _UnusedLedgerMetricsSource(),
  );
}

class _FakeAccountQueryService implements AccountQueryService {
  _FakeAccountQueryService(this._accounts);

  final List<Account> _accounts;

  @override
  Future<Map<String, Account>> findAccountsById() async => {
    for (final account in _accounts) account.id: account,
  };

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeTransactionReadRepository implements TransactionReadRepository {
  _FakeTransactionReadRepository({
    required this.transactions,
    this.reimbursementAggregate = const {},
  });

  final Map<String, Transaction> transactions;
  final Map<BusinessPurpose, TransactionChildAggregate> reimbursementAggregate;
  TransactionPageQuery? lastPageQuery;

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
  Stream<List<Transaction>> watchPage(TransactionPageQuery query) {
    lastPageQuery = query;
    return Stream.value([
      for (final transaction in transactions.values)
        if (!query.topLevelOnly || transaction.parentTransactionId == null)
          transaction,
    ]);
  }

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
  Stream<TransactionCleanupPreview> watchCleanupPreview(
    TransactionCleanupQuery query,
  ) => Stream.value(TransactionCleanupPreview.empty);

  @override
  Future<List<TransactionCleanupTarget>> findCleanupTargets(
    TransactionCleanupQuery query,
  ) async => const [];

  @override
  Future<List<CategoryTransactionTarget>> findCategoryTransactionTargets(
    String categoryId,
  ) async => const [];

  @override
  Stream<void> watchChanges() => Stream.value(null);
}

class _FakeEntryReadRepository implements EntryReadRepository {
  const _FakeEntryReadRepository(this._entriesByTransaction);

  final Map<String, List<Entry>> _entriesByTransaction;

  @override
  Future<Map<String, List<Entry>>> findByTransactionIds(
    Set<String> transactionIds,
  ) async => {
    for (final id in transactionIds)
      if (_entriesByTransaction[id] case final entries?) id: entries,
  };
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
