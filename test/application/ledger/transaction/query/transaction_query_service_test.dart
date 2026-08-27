import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/ledger/ledger_query_port_api.dart';
import 'package:smartflow/core/money/money.dart';

void main() {
  test('unified model fills children and derives reimbursement summary', () async {
    final parent = _transaction('parent', BusinessPurpose.reimbursementAdvance, 10000);
    // Child headers are not the cumulative source; settlement lines are.
    final refund = _transaction('refund', BusinessPurpose.refund, 9999, parentId: 'parent');
    final receipt = _transaction('receipt', BusinessPurpose.reimbursementReceipt, 8888, parentId: 'parent');
    final service = _service(
      transactions: {parent.id: parent, refund.id: refund, receipt.id: receipt},
      lines: {
        parent.id: [
          _line(parent.id, 2, TransactionRole.receivable, 10000, 'receivable'),
          _line(parent.id, 1, TransactionRole.settlementOut, 10000, 'card'),
        ],
        refund.id: [
          _line(refund.id, 1, TransactionRole.settlementIn, 1200, 'cash'),
          _line(refund.id, 2, TransactionRole.settlementIn, 800, 'bank'),
        ],
        receipt.id: [
          _line(receipt.id, 1, TransactionRole.settlementIn, 2500, 'cash'),
          _line(receipt.id, 2, TransactionRole.settlementIn, 3500, 'bank'),
        ],
      },
    );

    final detail = await service.findTransactionDetail(parent.id);

    expect(detail!.lines.map((line) => line.lineNo), [1, 2]);
    expect(detail.children.map((child) => child.id), ['refund', 'receipt']);
    expect(detail.children.every((child) => child.children.isEmpty), isTrue);
    expect(detail.refundedTotal.minorUnits, 2000);
    expect(detail.reimbursementReceivedTotal.minorUnits, 6000);
    expect(detail.reimbursementSummary?.outstanding.minorUnits, 2000);
  });

  test(
    'zero-cash reimbursement close contributes zero received amount',
    () async {
      final parent = _transaction(
        'parent',
        BusinessPurpose.reimbursementAdvance,
        10000,
      );
      final close = _transaction(
        'close',
        BusinessPurpose.reimbursementClose,
        0,
        parentId: parent.id,
      );
      final service = _service(
        transactions: {parent.id: parent, close.id: close},
        lines: {
          close.id: [
            _line(close.id, 1, TransactionRole.settlementIn, 0, 'cash'),
          ],
        },
      );

      final detail = await service.findTransactionDetail(parent.id);

      expect(detail!.reimbursementReceivedTotal, Money.zero());
      expect(detail.reimbursementSummary?.isClosed, isTrue);
    },
  );

  test('topLevelOnly false returns children both flat and nested', () async {
    final parent = _transaction('parent', BusinessPurpose.dailyExpense, 1000);
    final child = _transaction('child', BusinessPurpose.refund, 200, parentId: 'parent');
    final service = _service(transactions: {parent.id: parent, child.id: child});

    final items = await service.findTransactions(
      const TransactionListQuery(topLevelOnly: false),
    );

    expect(items.singleWhere((item) => item.id == 'parent').children.single.id, 'child');
    expect(items.singleWhere((item) => item.id == 'child').children, isEmpty);
  });

  test('account impacts remain the only entry projection', () async {
    final tx = _transaction('transfer', BusinessPurpose.transfer, 1000);
    final service = _service(
      transactions: {tx.id: tx},
      accounts: [_account('cash'), _account('bank')],
      entries: {
        tx.id: [
          _entry(tx.id, 'cash', EntryDirection.credit),
          _entry(tx.id, 'bank', EntryDirection.debit),
        ],
      },
    );

    final item = (await service.findTransactions(const TransactionListQuery())).single;

    expect(item.impactsByAccountId['cash']?.netChange.minorUnits, -1000);
    expect(item.impactsByAccountId['bank']?.netChange.minorUnits, 1000);
  });
}

TransactionQueryServiceImpl _service({
  required Map<String, Transaction> transactions,
  Map<String, List<TransactionLine>> lines = const {},
  Map<String, List<Entry>> entries = const {},
  List<Account> accounts = const [],
}) => TransactionQueryServiceImpl(
  transactionRead: _FakeTransactionReadRepository(transactions),
  lineRead: _FakeLineReadRepository(lines),
  entryRead: _FakeEntryReadRepository(entries),
  accountQuery: _FakeAccountQueryService(accounts),
  metricsSource: _UnusedMetricsSource(),
);

Transaction _transaction(
  String id,
  BusinessPurpose purpose,
  int amount, {
  String? parentId,
}) => Transaction(
  id: id,
  parentTransactionId: parentId,
  businessPurpose: purpose,
  occurredAt: DateTime(2026, 7, 23),
  primaryAmount: Money(minorUnits: amount),
  isExcludedFromStats: false,
  isExcludedFromBudget: false,
  sourceKind: SourceKind.manual,
);

TransactionLine _line(
  String transactionId,
  int lineNo,
  TransactionRole role,
  int amount,
  String accountId,
) => TransactionLine(
  id: '$transactionId-$lineNo',
  transactionId: transactionId,
  lineNo: lineNo,
  role: role,
  accountId: accountId,
  amount: Money(minorUnits: amount),
);

Entry _entry(String transactionId, String accountId, EntryDirection direction) => Entry(
  id: '$transactionId-$accountId',
  transactionId: transactionId,
  accountId: accountId,
  direction: direction,
  amount: const Money(minorUnits: 1000),
);

Account _account(String id) => Account(
  id: id,
  name: id,
  type: AccountType.asset,
  balance: Money.zero(),
);

class _FakeTransactionReadRepository implements TransactionReadRepository {
  _FakeTransactionReadRepository(this.transactions);
  final Map<String, Transaction> transactions;

  @override
  Future<Transaction?> findById(String id) async => transactions[id];

  @override
  Future<Map<String, DateTime>> findCreatedAtByIds(Set<String> ids) async => {
    for (final id in ids) id: DateTime(2026, 7, 23),
  };

  @override
  Future<Map<String, List<Transaction>>> findChildrenByParentIds(Set<String> parentIds) async {
    final result = <String, List<Transaction>>{};
    for (final tx in transactions.values) {
      final parentId = tx.parentTransactionId;
      if (parentId != null && parentIds.contains(parentId)) {
        result.putIfAbsent(parentId, () => []).add(tx);
      }
    }
    return result;
  }

  @override
  Stream<List<Transaction>> watchPage(TransactionPageQuery query) => Stream.value([
    for (final tx in transactions.values)
      if (!query.topLevelOnly || tx.parentTransactionId == null) tx,
  ]);

  @override
  Stream<void> watchChanges() => Stream.value(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLineReadRepository implements TransactionLineReadRepository {
  const _FakeLineReadRepository(this.lines);
  final Map<String, List<TransactionLine>> lines;

  @override
  Future<Map<String, List<TransactionLine>>> findByTransactionIds(Set<String> ids) async => {
    for (final id in ids) id: lines[id] ?? const [],
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeEntryReadRepository implements EntryReadRepository {
  const _FakeEntryReadRepository(this.entries);
  final Map<String, List<Entry>> entries;

  @override
  Future<Map<String, List<Entry>>> findByTransactionIds(Set<String> ids) async => {
    for (final id in ids) id: entries[id] ?? const [],
  };
}

class _FakeAccountQueryService implements AccountQueryService {
  const _FakeAccountQueryService(this.accounts);
  final List<Account> accounts;

  @override
  Future<Map<String, Account>> findAccountsById() async => {
    for (final account in accounts) account.id: account,
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedMetricsSource implements LedgerMetricsSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
