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

  test(
    'receivable collection list item carries principal and interest',
    () async {
      final collection = _transaction(
        id: 'collection',
        purpose: BusinessPurpose.receivableCollection,
        amount: 10500,
      );
      final service = _service(
        transactionRead: _FakeTransactionReadRepository(
          transactions: {'collection': collection},
        ),
        detailRead: const _FakeTransactionDetailReadRepository({
          'collection': [
            TransactionDetailRecord(
              id: 'principal',
              transactionId: 'collection',
              lineNo: 1,
              type: TransactionDetailType.receivableCollectionPrincipal,
              amount: Money(minorUnits: 10000),
            ),
            TransactionDetailRecord(
              id: 'interest',
              transactionId: 'collection',
              lineNo: 2,
              type: TransactionDetailType.receivableCollectionInterest,
              amount: Money(minorUnits: 500),
            ),
          ],
        }),
      );

      final item =
          (await service.watchTransactions(const TransactionListQuery()).first)
              .single;

      expect(item.adjustments.map((adjustment) => adjustment.kind), [
        TransactionAdjustmentKind.receivableCollectionPrincipal,
        TransactionAdjustmentKind.receivableCollectionInterest,
      ]);
      expect(item.adjustments.first.amount, const Money(minorUnits: 10000));
      expect(item.adjustments.last.amount, const Money(minorUnits: 500));
    },
  );

  test('transfer list item carries its fee adjustment', () async {
    final transfer = _transaction(
      id: 'transfer',
      purpose: BusinessPurpose.transfer,
      amount: 2000,
    );
    final service = _service(
      transactionRead: _FakeTransactionReadRepository(
        transactions: {'transfer': transfer},
      ),
      detailRead: const _FakeTransactionDetailReadRepository({
        'transfer': [
          TransactionDetailRecord(
            id: 'fee',
            transactionId: 'transfer',
            lineNo: 2,
            type: TransactionDetailType.transferFee,
            amount: Money(minorUnits: 300),
          ),
        ],
      }),
    );

    final item =
        (await service.watchTransactions(const TransactionListQuery()).first)
            .single;

    expect(item.adjustments, hasLength(1));
    expect(item.adjustments.single.kind, TransactionAdjustmentKind.transferFee);
    expect(item.adjustments.single.amount, const Money(minorUnits: 300));
  });

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

  test('projects primary category id and all account impacts', () async {
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

    expect(item.primaryCategoryId, 'dining');
    expect(item.impactsByAccountId.keys, {'dining', 'cash'});
    expect(
      item.impactsByAccountId['dining']?.debitAmount,
      const Money(minorUnits: 1000),
    );
    expect(
      item.impactsByAccountId['dining']?.netChange,
      const Money(minorUnits: 1000),
    );
    expect(
      item.impactsByAccountId['cash']?.creditAmount,
      const Money(minorUnits: 1000),
    );
    expect(
      item.impactsByAccountId['cash']?.netChange,
      const Money(minorUnits: -1000),
    );
  });

  test(
    'finds the unique usable settlement account last used by category',
    () async {
      final latestTransaction = _transaction(
        id: 'latest',
        purpose: BusinessPurpose.reimbursementAdvance,
        amount: 1000,
      );
      final transactionRead = _FakeTransactionReadRepository(
        transactions: {'latest': latestTransaction},
        latestCategoryTransaction: latestTransaction,
      );
      final service = _service(
        transactionRead: transactionRead,
        entryRead: _FakeEntryReadRepository({
          'latest': [
            _entry('company', 'latest', 'company', EntryDirection.debit, 1000),
            _entry('card', 'latest', 'card', EntryDirection.credit, 1000),
          ],
        }),
        accounts: [
          _account('food', AccountType.expense),
          _account(
            'company',
            AccountType.asset,
            subtype: AccountSubtype.receivable,
          ),
          _account('card', AccountType.liability),
        ],
      );

      final accountId = await service.findLastUsedSettlementAccountId('food');

      expect(accountId, 'card');
      expect(transactionRead.lastCategoryQuery?.categoryId, 'food');
      expect(
        transactionRead.lastCategoryQuery?.hierarchy,
        TransactionHierarchyFilter.topLevel,
      );
    },
  );

  test('passes multiple physical category ids through', () async {
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
      const TransactionListQuery(categoryAccountIds: {'food', 'dining'}),
    );

    expect(transactionRead.lastPageQuery?.categoryAccountIds, {
      'food',
      'dining',
    });
  });

  test('keeps valid physical category ids and drops invalid ones', () async {
    final transactionRead = _FakeTransactionReadRepository(transactions: {});
    final service = _service(
      transactionRead: transactionRead,
      accounts: [
        _account('food', AccountType.expense),
        _account('dining', AccountType.expense, parentId: 'food'),
      ],
    );

    await service.findTransactions(
      const TransactionListQuery(categoryAccountIds: {'dining', 'missing'}),
    );

    expect(transactionRead.lastPageQuery?.categoryAccountIds, {'dining'});
  });

  test(
    'returns empty list when a category filter has no valid accounts',
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
        const TransactionListQuery(categoryAccountIds: {'missing'}),
      );

      expect(items, isEmpty);
      expect(transactionRead.lastPageQuery, isNull);
    },
  );

  test('passes multiple settlement account ids through', () async {
    final transactionRead = _FakeTransactionReadRepository(transactions: {});
    final service = _service(
      transactionRead: transactionRead,
      accounts: [
        _account('cash', AccountType.asset),
        _account('card', AccountType.liability),
      ],
    );

    await service.findTransactions(
      const TransactionListQuery(settlementAccountIds: {'cash', 'card'}),
    );

    expect(transactionRead.lastPageQuery?.settlementAccountIds, {
      'cash',
      'card',
    });
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
        TransactionListQuery(settlementAccountIds: {accountId}),
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

      final item = (await service.findTransactions(
        const TransactionListQuery(),
      )).single;

      expect(item.primaryCategoryId, 'dining');
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

    final item = (await service.findTransactions(
      const TransactionListQuery(),
    )).single;

    expect(item.primaryCategoryId, isNull);
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

    final item = (await service.findTransactions(
      const TransactionListQuery(),
    )).single;

    expect(item.impactsByAccountId.keys, {'cash', 'opening-equity'});
  });

  test('aggregates every account type and keeps zero net activity', () async {
    final transaction = _transaction(
      id: 'mixed',
      purpose: BusinessPurpose.transfer,
      amount: 1000,
    );
    final service = _service(
      transactionRead: _FakeTransactionReadRepository(
        transactions: {'mixed': transaction},
      ),
      entryRead: _FakeEntryReadRepository({
        'mixed': [
          _entry('a1', 'mixed', 'asset', EntryDirection.debit, 100),
          _entry('a2', 'mixed', 'asset', EntryDirection.credit, 40),
          _entry('x1', 'mixed', 'expense', EntryDirection.debit, 100),
          _entry('x2', 'mixed', 'expense', EntryDirection.credit, 100),
          _entry('l1', 'mixed', 'liability', EntryDirection.credit, 90),
          _entry('l2', 'mixed', 'liability', EntryDirection.debit, 20),
          _entry('i1', 'mixed', 'income', EntryDirection.credit, 50),
          _entry('e1', 'mixed', 'equity', EntryDirection.debit, 30),
        ],
      }),
      accounts: [
        _account('asset', AccountType.asset),
        _account('expense', AccountType.expense),
        _account('liability', AccountType.liability),
        _account('income', AccountType.income),
        _account('equity', AccountType.equity),
      ],
    );

    final impacts = (await service.findTransactions(
      const TransactionListQuery(),
    )).single.impactsByAccountId;

    expect(impacts.keys, {'asset', 'expense', 'liability', 'income', 'equity'});
    expect(impacts['asset']?.debitAmount.minorUnits, 100);
    expect(impacts['asset']?.creditAmount.minorUnits, 40);
    expect(impacts['asset']?.netChange.minorUnits, 60);
    expect(impacts['expense']?.netChange.minorUnits, 0);
    expect(impacts['liability']?.netChange.minorUnits, 70);
    expect(impacts['income']?.netChange.minorUnits, 50);
    expect(impacts['equity']?.netChange.minorUnits, -30);
  });

  test(
    'keeps parent and child impacts separate from group adjustments',
    () async {
      final parent = _transaction(
        id: 'parent',
        purpose: BusinessPurpose.dailyExpense,
        amount: 2000,
      );
      final refund = _transaction(
        id: 'refund',
        parentId: 'parent',
        purpose: BusinessPurpose.refund,
        amount: 200,
      );
      final service = _service(
        transactionRead: _FakeTransactionReadRepository(
          transactions: {'parent': parent, 'refund': refund},
        ),
        entryRead: _FakeEntryReadRepository({
          'parent': [
            _entry('p1', 'parent', 'food', EntryDirection.debit, 2000),
            _entry('p2', 'parent', 'cash', EntryDirection.credit, 2000),
          ],
          'refund': [
            _entry('r1', 'refund', 'food', EntryDirection.credit, 200),
            _entry('r2', 'refund', 'cash', EntryDirection.debit, 200),
          ],
        }),
        accounts: [
          _account('food', AccountType.expense),
          _account('cash', AccountType.asset),
        ],
      );

      final items = await service.findTransactions(
        const TransactionListQuery(topLevelOnly: false),
      );
      final parentItem = items.singleWhere((item) => item.id == 'parent');
      final refundItem = items.singleWhere((item) => item.id == 'refund');

      expect(parentItem.impactsByAccountId['food']?.netChange.minorUnits, 2000);
      expect(
        parentItem.impactsByAccountId['cash']?.netChange.minorUnits,
        -2000,
      );
      expect(
        parentItem.adjustments.single.kind,
        TransactionAdjustmentKind.refund,
      );
      expect(refundItem.impactsByAccountId['food']?.netChange.minorUnits, -200);
      expect(refundItem.impactsByAccountId['cash']?.netChange.minorUnits, 200);
      expect(refundItem.adjustments, isEmpty);
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
  AccountSubtype? subtype,
}) {
  return Account(
    id: id,
    name: name ?? id,
    type: type,
    parentId: parentId,
    iconKey: iconKey,
    archivedAt: archivedAt,
    systemKey: systemKey,
    subtype: subtype,
    balance: const Money(minorUnits: 0),
  );
}

TransactionQueryServiceImpl _service({
  required _FakeTransactionReadRepository transactionRead,
  _FakeEntryReadRepository entryRead = const _FakeEntryReadRepository({}),
  _FakeTransactionDetailReadRepository detailRead =
      const _FakeTransactionDetailReadRepository(),
  List<Account> accounts = const [],
}) {
  return TransactionQueryServiceImpl(
    transactionRead: transactionRead,
    entryRead: entryRead,
    detailRead: detailRead,
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
    this.latestCategoryTransaction,
  });

  final Map<String, Transaction> transactions;
  final Map<BusinessPurpose, TransactionChildAggregate> reimbursementAggregate;
  final Transaction? latestCategoryTransaction;
  TransactionPageQuery? lastPageQuery;
  CategoryTransactionQuery? lastCategoryQuery;

  @override
  Future<Transaction?> findById(String id) async => transactions[id];

  @override
  Future<DateTime?> findCreatedAt(String id) async => null;

  @override
  Future<List<Transaction>> findByIds(Set<String> ids) async => [
    for (final id in ids) ?transactions[id],
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
  Future<Transaction?> findLatestByCategory(
    CategoryTransactionQuery query,
  ) async {
    lastCategoryQuery = query;
    return latestCategoryTransaction;
  }

  @override
  Stream<void> watchChanges() => Stream.value(null);
}

class _FakeEntryReadRepository implements EntryReadRepository {
  const _FakeEntryReadRepository(this._entriesByTransaction);

  final Map<String, List<Entry>> _entriesByTransaction;

  @override
  Future<Map<String, List<Entry>>> findByTransactionIds(
    Set<String> transactionIds,
  ) async => {for (final id in transactionIds) id: ?_entriesByTransaction[id]};
}

class _FakeTransactionDetailReadRepository
    implements TransactionDetailReadRepository {
  const _FakeTransactionDetailReadRepository([
    this._detailsByTransaction = const {},
  ]);

  final Map<String, List<TransactionDetailRecord>> _detailsByTransaction;

  @override
  Future<Map<String, List<TransactionDetailRecord>>> findByTransactionIds(
    Set<String> transactionIds,
  ) async => {for (final id in transactionIds) id: ?_detailsByTransaction[id]};

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
  Future<List<TagAggregate>> aggregateByTag({
    required Set<AccountType> accountTypes,
    required TransactionScopeFilter scope,
    DateTimeWindow window = const DateTimeWindow(),
  }) => throw UnimplementedError();

  @override
  Stream<void> watchChanges() => const Stream.empty();
}
