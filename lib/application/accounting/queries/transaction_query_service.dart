import '../../../core/money/money.dart';
import 'package:smartflow/domain/accounting/entities/entry.dart';
import 'package:smartflow/domain/accounting/entities/transaction.dart';
import 'package:smartflow/domain/accounting/entities/transaction_detail_record.dart';
import 'package:smartflow/domain/accounting/enums/accounting_enums.dart';
import '../queries/transaction_queries.dart';
import '../queries/transaction_scope.dart';
import '../read_models/transaction_read_models.dart';
import 'balance_aggregate_repository.dart';
import 'entry_read_repository.dart';
import 'transaction_detail_read_repository.dart';
import 'transaction_read_repository.dart';

abstract interface class TransactionQueryService {
  Stream<List<TransactionListItem>> watchTransactions(
    TransactionListQuery query,
  );

  Stream<CashflowSummary> watchCashflowSummary(CashflowSummaryQuery query);

  Stream<TransactionDetail?> watchTransactionDetail(int transactionId);

  /// 一次性取一笔的聚合视图(transaction + entries + details + 子树 + 历史)。
  /// 写路径(correct / delete / updateBasics)取 original 快照用,无需 stream 订阅。
  Future<TransactionDetail?> findTransactionDetail(int transactionId);

  /// 批量取一组交易的会计事实(transaction + entries + details),不含子树 / 历史。
  /// 用于批量取消等只关心账本事实的场景。
  Future<List<TransactionDetail>> findTransactionFacts(Set<int> transactionIds);

  Stream<List<TransactionHistorySnapshot>> watchTransactionHistory(
    int rootTransactionId,
  );

  Future<Transaction?> findTransactionById(int transactionId);

  Future<Money> getRefundedTotal(int rootTransactionId);

  Future<ReimbursementSummary?> getReimbursementSummary(int rootTransactionId);

  Future<int> getDetailAmountSum({
    required Iterable<int> transactionIds,
    required TransactionDetailType detailType,
  });
}

class TransactionQueryServiceImpl implements TransactionQueryService {
  const TransactionQueryServiceImpl({
    required TransactionReadRepository transactionRead,
    required EntryReadRepository entryRead,
    required TransactionDetailReadRepository detailRead,
    required BalanceAggregateRepository balanceAggregate,
  }) : _txRead = transactionRead,
       _entryRead = entryRead,
       _detailRead = detailRead,
       _balanceAggregate = balanceAggregate;

  final TransactionReadRepository _txRead;
  final EntryReadRepository _entryRead;
  final TransactionDetailReadRepository _detailRead;
  final BalanceAggregateRepository _balanceAggregate;

  // ---------- 列表场景 ----------

  @override
  Stream<List<TransactionListItem>> watchTransactions(
    TransactionListQuery query,
  ) {
    return _txRead.watchPage(query).asyncMap(_projectListItems);
  }

  Future<List<TransactionListItem>> _projectListItems(
    List<Transaction> page,
  ) async {
    if (page.isEmpty) return const [];

    final pageTxIds = page.map((t) => t.id).toSet();
    final refundRootIds =
        page
            .where((t) => t.businessPurpose == BusinessPurpose.dailyExpense)
            .map((t) => t.rootTransactionId)
            .toSet();
    final reimbAdvanceRootIds =
        page
            .where(
              (t) => t.businessPurpose == BusinessPurpose.reimbursementAdvance,
            )
            .map((t) => t.rootTransactionId)
            .toSet();

    final results = await Future.wait([
      _txRead.aggregateChildren(
        rootIds: refundRootIds,
        purposes: const {BusinessPurpose.refund},
        states: const {BusinessState.current},
      ),
      _txRead.aggregateChildren(
        rootIds: reimbAdvanceRootIds,
        purposes: const {
          BusinessPurpose.reimbursementReceipt,
          BusinessPurpose.reimbursementClose,
        },
        states: const {BusinessState.current},
      ),
      _txRead.aggregateChildDetailAmounts(
        rootIds: reimbAdvanceRootIds,
        detailTypes: const {
          TransactionDetailType.reimbursementGapIncome,
          TransactionDetailType.reimbursementGapExpense,
        },
        states: const {BusinessState.current},
      ),
      _entryRead.findByTransactionIds(pageTxIds),
      _detailRead.findByTransactionIds(pageTxIds),
    ]);

    final refundAgg = results[0] as Map<int, TransactionChildAggregate>;
    final reimbAgg = results[1] as Map<int, TransactionChildAggregate>;
    final gapAgg = results[2] as Map<int, Map<TransactionDetailType, int>>;
    final entriesByTx = results[3] as Map<int, List<dynamic>>;
    final detailsByTx = results[4] as Map<int, List<dynamic>>;

    return [
      for (final t in page)
        TransactionListItem(
          id: t.id,
          rootTransactionId: t.rootTransactionId,
          parentTransactionId: t.parentTransactionId,
          businessPurpose: t.businessPurpose,
          businessState: t.businessState,
          occurredAt: t.occurredAt,
          primaryAmount: t.primaryAmount,
          counterpartyName: t.counterpartyName,
          note: t.note,
          isExcludedFromStats: t.isExcludedFromStats,
          isExcludedFromBudget: t.isExcludedFromBudget,
          reimbursementExpenseAccountId: t.reimbursementExpenseAccountId,
          entries: List.unmodifiable(entriesByTx[t.id] ?? const []),
          details: List.unmodifiable(detailsByTx[t.id] ?? const []),
          refundedTotal: _refundedTotalFor(t, refundAgg),
          refundChildCount: _refundCountFor(t, refundAgg),
          reimbursementReceivedTotal: _reimbReceivedFor(t, reimbAgg),
          reimbursementChildCount: _reimbCountFor(t, reimbAgg),
          reimbursementGapIncome: _gapMoneyFor(
            t,
            gapAgg,
            TransactionDetailType.reimbursementGapIncome,
          ),
          reimbursementGapExpense: _gapMoneyFor(
            t,
            gapAgg,
            TransactionDetailType.reimbursementGapExpense,
          ),
        ),
    ];
  }

  Money? _refundedTotalFor(
    Transaction t,
    Map<int, TransactionChildAggregate> agg,
  ) {
    if (t.parentTransactionId != null) return null;
    if (t.businessPurpose != BusinessPurpose.dailyExpense) return null;
    final entry = agg[t.rootTransactionId];
    if (entry == null || entry.sumMinor == 0) return null;
    return Money(minorUnits: entry.sumMinor);
  }

  int _refundCountFor(Transaction t, Map<int, TransactionChildAggregate> agg) {
    if (t.parentTransactionId != null) return 0;
    if (t.businessPurpose != BusinessPurpose.dailyExpense) return 0;
    return agg[t.rootTransactionId]?.count ?? 0;
  }

  Money? _reimbReceivedFor(
    Transaction t,
    Map<int, TransactionChildAggregate> agg,
  ) {
    if (t.parentTransactionId != null) return null;
    if (t.businessPurpose != BusinessPurpose.reimbursementAdvance) return null;
    final entry = agg[t.rootTransactionId];
    if (entry == null || entry.sumMinor == 0) return null;
    return Money(minorUnits: entry.sumMinor);
  }

  int _reimbCountFor(Transaction t, Map<int, TransactionChildAggregate> agg) {
    if (t.parentTransactionId != null) return 0;
    if (t.businessPurpose != BusinessPurpose.reimbursementAdvance) return 0;
    return agg[t.rootTransactionId]?.count ?? 0;
  }

  Money? _gapMoneyFor(
    Transaction t,
    Map<int, Map<TransactionDetailType, int>> agg,
    TransactionDetailType type,
  ) {
    if (t.parentTransactionId != null) return null;
    if (t.businessPurpose != BusinessPurpose.reimbursementAdvance) return null;
    final amount = agg[t.rootTransactionId]?[type] ?? 0;
    if (amount == 0) return null;
    return Money(minorUnits: amount);
  }

  // ---------- 现金流 summary ----------

  @override
  Stream<CashflowSummary> watchCashflowSummary(CashflowSummaryQuery query) {
    return Stream.fromFuture(_loadCashflowSummary(query)).asBroadcastStream();
  }

  Future<CashflowSummary> _loadCashflowSummary(
    CashflowSummaryQuery query,
  ) async {
    final result = await _balanceAggregate.aggregateByAccountType(
      accountTypes: const {AccountType.income, AccountType.expense},
      scope: TransactionScopeFilter.stats,
      window: DateTimeWindow(
        from: query.occurredFrom,
        until: query.occurredUntil,
      ),
    );
    final incomeMinor = result[AccountType.income] ?? 0;
    final expenseMinor = result[AccountType.expense] ?? 0;
    return CashflowSummary(
      income: Money(minorUnits: incomeMinor),
      expense: Money(minorUnits: expenseMinor),
    );
  }

  // ---------- 详情场景 ----------

  @override
  Stream<TransactionDetail?> watchTransactionDetail(int transactionId) {
    return _txRead.watchChanges().asyncMap((_) => _loadDetail(transactionId));
  }

  @override
  Future<TransactionDetail?> findTransactionDetail(int transactionId) =>
      _loadDetail(transactionId);

  @override
  Future<List<TransactionDetail>> findTransactionFacts(
    Set<int> transactionIds,
  ) async {
    if (transactionIds.isEmpty) return const [];
    final transactions = await _txRead.findByIds(transactionIds);
    if (transactions.isEmpty) return const [];
    final fetchedIds = transactions.map((t) => t.id).toSet();
    final entriesF = _entryRead.findByTransactionIds(fetchedIds);
    final detailsF = _detailRead.findByTransactionIds(fetchedIds);
    await Future.wait<void>([entriesF, detailsF]);
    final entriesByTx = await entriesF;
    final detailsByTx = await detailsF;
    return [
      for (final t in transactions)
        TransactionDetail(
          transaction: t,
          entries: List<Entry>.unmodifiable(
            entriesByTx[t.id] ?? const <Entry>[],
          ),
          details: List<TransactionDetailRecord>.unmodifiable(
            detailsByTx[t.id] ?? const <TransactionDetailRecord>[],
          ),
        ),
    ];
  }

  Future<TransactionDetail?> _loadDetail(int transactionId) async {
    final transaction = await _txRead.findById(transactionId);
    if (transaction == null) return null;

    final rootId = transaction.rootTransactionId;
    final results = await Future.wait([
      _entryRead.findByTransactionIds({transactionId}),
      _detailRead.findByTransactionIds({transactionId}),
      _txRead.findChildren(
        parentId: transactionId,
        states: const {BusinessState.current},
      ),
      _txRead.findRootDescendants(
        rootId: rootId,
        excludeId: transactionId,
        excludeStateMutation: (
          state: BusinessState.current,
          mutationKind: MutationKind.original,
        ),
      ),
    ]);

    final entries =
        (results[0] as Map<int, List<dynamic>>)[transactionId] ?? const [];
    final details =
        (results[1] as Map<int, List<dynamic>>)[transactionId] ?? const [];
    final childrenTxs = results[2] as List<Transaction>;
    final historyTxs = results[3] as List<Transaction>;

    final childrenListItems = await _projectListItems(childrenTxs);
    final historySnapshots = await _projectHistorySnapshots(historyTxs);

    Money? refundedTotal;
    if (transaction.businessPurpose == BusinessPurpose.dailyExpense) {
      refundedTotal = await getRefundedTotal(rootId);
    }
    ReimbursementSummary? reimbursementSummary;
    if (transaction.businessPurpose == BusinessPurpose.reimbursementAdvance) {
      reimbursementSummary = await getReimbursementSummary(rootId);
    }

    return TransactionDetail(
      transaction: transaction,
      entries: List.unmodifiable(entries),
      details: List.unmodifiable(details),
      children: childrenListItems,
      history: historySnapshots,
      refundedTotal: refundedTotal,
      reimbursementSummary: reimbursementSummary,
    );
  }

  // ---------- 更正链场景 ----------

  @override
  Stream<List<TransactionHistorySnapshot>> watchTransactionHistory(
    int rootTransactionId,
  ) {
    return _txRead.watchChanges().asyncMap((_) async {
      final txs = await _txRead.findRootDescendants(
        rootId: rootTransactionId,
        excludeStateMutation: (
          state: BusinessState.current,
          mutationKind: MutationKind.original,
        ),
      );
      return _projectHistorySnapshots(txs);
    });
  }

  Future<List<TransactionHistorySnapshot>> _projectHistorySnapshots(
    List<Transaction> txs,
  ) async {
    if (txs.isEmpty) return const [];

    final txIds = txs.map((t) => t.id).toSet();
    final results = await Future.wait([
      _entryRead.findByTransactionIds(txIds),
      _detailRead.findByTransactionIds(txIds),
    ]);
    final entriesByTx = results[0] as Map<int, List<dynamic>>;
    final detailsByTx = results[1] as Map<int, List<dynamic>>;

    return [
      for (final t in txs)
        TransactionHistorySnapshot(
          id: t.id,
          rootTransactionId: t.rootTransactionId,
          parentTransactionId: t.parentTransactionId,
          businessPurpose: t.businessPurpose,
          businessState: t.businessState,
          occurredAt: t.occurredAt,
          primaryAmount: t.primaryAmount,
          counterpartyName: t.counterpartyName,
          note: t.note,
          mutationKind: t.mutationKind,
          mutationReason: t.mutationReason,
          mutationPreviousTransactionId: t.mutationPreviousTransactionId,
          createdAt: t.createdAt,
          entries: List.unmodifiable(entriesByTx[t.id] ?? const []),
          details: List.unmodifiable(detailsByTx[t.id] ?? const []),
        ),
    ];
  }

  // ---------- 标量查询(便捷方法) ----------

  @override
  Future<Transaction?> findTransactionById(int transactionId) {
    return _txRead.findById(transactionId);
  }

  @override
  Future<Money> getRefundedTotal(int rootTransactionId) async {
    final result = await _txRead.aggregateChildren(
      rootIds: {rootTransactionId},
      purposes: const {BusinessPurpose.refund},
      states: const {BusinessState.current},
    );
    return Money(minorUnits: result[rootTransactionId]?.sumMinor ?? 0);
  }

  @override
  Future<ReimbursementSummary?> getReimbursementSummary(
    int rootTransactionId,
  ) async {
    final advance = await _txRead.findById(rootTransactionId);
    if (advance == null ||
        advance.businessPurpose != BusinessPurpose.reimbursementAdvance) {
      return null;
    }

    final byPurpose = await _txRead.aggregateChildrenByPurpose(
      rootIds: {rootTransactionId},
      purposes: const {
        BusinessPurpose.reimbursementReceipt,
        BusinessPurpose.reimbursementClose,
      },
      states: const {BusinessState.current},
    );
    final bucket = byPurpose[rootTransactionId] ?? const {};
    final receiptAgg =
        bucket[BusinessPurpose.reimbursementReceipt] ??
        TransactionChildAggregate.empty;
    final closeAgg =
        bucket[BusinessPurpose.reimbursementClose] ??
        TransactionChildAggregate.empty;
    final receivedMinor = receiptAgg.sumMinor + closeAgg.sumMinor;
    final isClosed = closeAgg.count > 0;

    final advanceAmount = advance.primaryAmount;
    final receivedAmount = Money(minorUnits: receivedMinor);
    final outstanding =
        isClosed ? const Money(minorUnits: 0) : advanceAmount - receivedAmount;

    return ReimbursementSummary(
      advanceAmount: advanceAmount,
      receivedAmount: receivedAmount,
      outstanding: outstanding,
      isClosed: isClosed,
    );
  }

  @override
  Future<int> getDetailAmountSum({
    required Iterable<int> transactionIds,
    required TransactionDetailType detailType,
  }) async {
    final ids = transactionIds.toSet();
    if (ids.isEmpty) return 0;
    final result = await _detailRead.sumOwnByType(
      transactionIds: ids,
      detailTypes: {detailType},
    );
    var total = 0;
    for (final byType in result.values) {
      total += byType[detailType] ?? 0;
    }
    return total;
  }
}
