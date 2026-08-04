import 'dart:async';

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
      const TransactionListQuery(
        category: CategorySelection.withDescendants('food'),
      ),
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
      const TransactionListQuery(
        category: CategorySelection.withDescendants('dining'),
      ),
    );

    expect(transactionRead.lastPageQuery?.categoryAccountIds, {'dining'});
  });

  test(
    'own-only category selection keeps the first-level category unexpanded',
    () async {
      final transactionRead = _FakeTransactionReadRepository(transactions: {});
      final service = _service(
        transactionRead: transactionRead,
        accounts: [
          _account('food', AccountType.expense),
          _account('dining', AccountType.expense, parentId: 'food'),
        ],
      );

      await service.findTransactions(
        const TransactionListQuery(category: CategorySelection.ownOnly('food')),
      );

      expect(transactionRead.lastPageQuery?.categoryAccountIds, {'food'});
    },
  );

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
        const TransactionListQuery(
          category: CategorySelection.withDescendants('missing'),
        ),
      );

      expect(items, isEmpty);
      expect(transactionRead.lastPageQuery, isNull);
    },
  );

  test('passes the settlement account filter through unchanged', () async {
    final transactionRead = _FakeTransactionReadRepository(transactions: {});
    final service = _service(
      transactionRead: transactionRead,
      accounts: [_account('cash', AccountType.asset)],
    );

    await service.findTransactions(
      const TransactionListQuery(settlementAccountId: 'cash'),
    );

    expect(transactionRead.lastPageQuery?.settlementAccountIds, {'cash'});
    expect(transactionRead.lastPageQuery?.categoryAccountIds, isNull);
  });

  test('rejects non-user and archived settlement account filters', () async {
    final accounts = [
      _account('food', AccountType.expense),
      _account(
        'archived-cash',
        AccountType.asset,
        archivedAt: DateTime(2026, 1),
      ),
    ];
    for (final accountId in ['missing', 'food', 'archived-cash']) {
      final transactionRead = _FakeTransactionReadRepository(
        transactions: {
          'expense': _transaction(
            id: 'expense',
            purpose: BusinessPurpose.dailyExpense,
            amount: 1000,
          ),
        },
      );
      final service = _service(
        transactionRead: transactionRead,
        accounts: accounts,
      );

      final items = await service.findTransactions(
        TransactionListQuery(settlementAccountId: accountId),
      );

      expect(items, isEmpty);
      expect(transactionRead.lastPageQuery, isNull);
    }
  });

  test(
    'projects the unique expense role entry instead of the first expense account',
    () async {
      final expense = _transaction(
        id: 'expense',
        purpose: BusinessPurpose.dailyExpense,
        amount: 1000,
      );
      final service = _service(
        transactionRead: _FakeTransactionReadRepository(
          transactions: {'expense': expense},
        ),
        entryRead: _FakeEntryReadRepository({
          'expense': [
            _entry(
              'system-fee',
              'expense',
              'fee-expense',
              EntryDirection.debit,
              200,
            ),
            _entry('category', 'expense', 'dining', EntryDirection.debit, 1000),
            _entry('cash', 'expense', 'cash', EntryDirection.credit, 1200),
          ],
        }),
        accounts: [
          _account(
            'fee-expense',
            AccountType.expense,
            name: '手续费',
            systemKey: SystemKey.feeExpense,
          ),
          _account('dining', AccountType.expense, name: '餐饮'),
          _account('cash', AccountType.asset, name: '现金'),
        ],
      );

      final item =
          (await service.findTransactions(const TransactionListQuery())).single;

      expect(item.category?.id, 'dining');
    },
  );

  test('returns no income category when role entries are not unique', () async {
    final income = _transaction(
      id: 'income',
      purpose: BusinessPurpose.dailyIncome,
      amount: 1000,
    );
    final service = _service(
      transactionRead: _FakeTransactionReadRepository(
        transactions: {'income': income},
      ),
      entryRead: _FakeEntryReadRepository({
        'income': [
          _entry('salary', 'income', 'salary', EntryDirection.credit, 1000),
          _entry('bonus', 'income', 'bonus', EntryDirection.credit, 1000),
          _entry('cash', 'income', 'cash', EntryDirection.debit, 2000),
        ],
      }),
      accounts: [
        _account('salary', AccountType.income, name: '工资'),
        _account('bonus', AccountType.income, name: '奖金'),
        _account('cash', AccountType.asset, name: '现金'),
      ],
    );

    final item =
        (await service.findTransactions(const TransactionListQuery())).single;

    expect(item.category, isNull);
  });

  test('projects the system counterpart for opening balance flows', () async {
    final opening = _transaction(
      id: 'opening',
      purpose: BusinessPurpose.openingBalance,
      amount: 1000,
    );
    final service = _service(
      transactionRead: _FakeTransactionReadRepository(
        transactions: {'opening': opening},
      ),
      entryRead: _FakeEntryReadRepository({
        'opening': [
          _entry('cash', 'opening', 'cash', EntryDirection.debit, 1000),
          _entry(
            'equity',
            'opening',
            'opening-equity',
            EntryDirection.credit,
            1000,
          ),
        ],
      }),
      accounts: [
        _account('cash', AccountType.asset, name: '现金'),
        _account(
          'opening-equity',
          AccountType.equity,
          name: '系统期初余额',
          systemKey: SystemKey.openingBalance,
        ),
      ],
    );

    final item =
        (await service.findTransactions(const TransactionListQuery())).single;

    expect(item.settlementEntries.map((entry) => entry.accountId), [
      'cash',
      'opening-equity',
    ]);
  });

  test(
    'reprojects category snapshots and re-expands a subscribed filter',
    () async {
      final changes = StreamController<void>();
      addTearDown(changes.close);
      final transactionRead = _FakeTransactionReadRepository(
        transactions: {
          'expense': _transaction(
            id: 'expense',
            purpose: BusinessPurpose.dailyExpense,
            amount: 1000,
          ),
        },
        changes: changes.stream,
      );
      final accounts = [
        _account('food', AccountType.expense, name: '餐饮'),
        _account(
          'dining',
          AccountType.expense,
          name: '聚餐',
          iconKey: 'bowl',
          parentId: 'food',
        ),
        _account('cash', AccountType.asset, name: '现金'),
      ];
      final service = _service(
        transactionRead: transactionRead,
        accounts: accounts,
        entryRead: _FakeEntryReadRepository({
          'expense': [
            _entry('category', 'expense', 'dining', EntryDirection.debit, 1000),
            _entry('cash', 'expense', 'cash', EntryDirection.credit, 1000),
          ],
        }),
      );
      final first = Completer<TransactionListReadModel>();
      final second = Completer<TransactionListReadModel>();
      final third = Completer<void>();
      var emissionCount = 0;
      final subscription = service
          .watchTransactions(
            const TransactionListQuery(
              category: CategorySelection.withDescendants('food'),
            ),
          )
          .listen((items) {
            emissionCount += 1;
            if (emissionCount == 1) first.complete(items.single);
            if (emissionCount == 2) second.complete(items.single);
            if (emissionCount == 3) third.complete();
          });
      addTearDown(subscription.cancel);

      changes.add(null);
      expect((await first.future).category?.name, '聚餐');
      expect(transactionRead.lastPageQuery?.categoryAccountIds, {
        'food',
        'dining',
      });

      accounts[1] = _account(
        'dining',
        AccountType.expense,
        name: '外食',
        iconKey: 'fork',
        parentId: 'food',
      );
      changes.add(null);
      final renamed = await second.future;
      expect(renamed.category?.name, '外食');
      expect(renamed.category?.iconKey, 'fork');

      accounts[1] = _account('dining', AccountType.expense, name: '外食');
      changes.add(null);
      await third.future;
      expect(transactionRead.lastPageQuery?.categoryAccountIds, {'food'});
    },
  );
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
  DateTime? archivedAt,
  SystemKey? systemKey,
}) {
  return Account(
    id: id,
    name: name ?? id,
    type: type,
    parentId: parentId,
    iconKey: iconKey,
    archivedAt: archivedAt,
    systemKey: systemKey,
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
    this.changes,
  });

  final Map<String, Transaction> transactions;
  final Map<BusinessPurpose, TransactionChildAggregate> reimbursementAggregate;
  final Stream<void>? changes;
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
  Stream<void> watchChanges() => changes ?? Stream.value(null);
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
