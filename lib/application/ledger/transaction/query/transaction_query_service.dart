import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/entry.dart';
import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/entity/transaction_detail_record.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

import '../../metrics/query/port/ledger_metrics_source.dart';
import 'port/entry_read_repository.dart';
import 'port/transaction_detail_read_repository.dart';
import 'port/transaction_read_repository.dart';
import 'transaction_queries.dart';
import 'transaction_read_models.dart';
import 'transaction_scope.dart';

abstract interface class TransactionQueryService {
  Stream<List<TransactionListReadModel>> watchTransactions(
    TransactionListQuery query,
  );

  Future<List<TransactionListReadModel>> findTransactions(
    TransactionListQuery query,
  );

  Stream<CashflowSummary> watchCashflowSummary(CashflowSummaryQuery query);

  Stream<TransactionDetail?> watchTransactionDetail(String transactionId);

  Future<TransactionDetail?> findTransactionDetail(String transactionId);

  Future<TransactionDetail?> findParentTransactionDetail(
    String parentTransactionId,
  );

  Future<List<TransactionDetail>> findTransactionFacts(
    Set<String> transactionIds,
  );

  Future<Transaction?> findTransactionById(String transactionId);

  Future<Money> getRefundedTotal(String parentTransactionId);

  Future<ReimbursementSummary?> getReimbursementSummary(
    String parentTransactionId,
  );

  Future<int> getDetailAmountSum({
    required Iterable<String> transactionIds,
    required TransactionDetailType detailType,
  });

  Stream<TransactionCleanupPreview> watchCleanupPreview(
    TransactionCleanupQuery query,
  );
}

class TransactionQueryServiceImpl implements TransactionQueryService {
  const TransactionQueryServiceImpl({
    required TransactionReadRepository transactionRead,
    required EntryReadRepository entryRead,
    required TransactionDetailReadRepository detailRead,
    required LedgerMetricsSource metricsSource,
  }) : _txRead = transactionRead,
       _entryRead = entryRead,
       _detailRead = detailRead,
       _metricsSource = metricsSource;

  final TransactionReadRepository _txRead;
  final EntryReadRepository _entryRead;
  final TransactionDetailReadRepository _detailRead;
  final LedgerMetricsSource _metricsSource;

  @override
  Stream<List<TransactionListReadModel>> watchTransactions(
    TransactionListQuery query,
  ) {
    return _txRead.watchPage(query).asyncMap(_projectListItems);
  }

  @override
  Future<List<TransactionListReadModel>> findTransactions(
    TransactionListQuery query,
  ) async {
    return _projectListItems(await _txRead.watchPage(query).first);
  }

  Future<List<TransactionListReadModel>> _projectListItems(
    List<Transaction> page,
  ) async {
    if (page.isEmpty) return const [];
    final pageIds = page.map((transaction) => transaction.id).toSet();
    final refundParentIds =
        page
            .where(
              (transaction) =>
                  transaction.parentTransactionId == null &&
                  (transaction.businessPurpose ==
                          BusinessPurpose.dailyExpense ||
                      transaction.businessPurpose ==
                          BusinessPurpose.reimbursementAdvance),
            )
            .map((transaction) => transaction.id)
            .toSet();
    final reimbursementParentIds =
        page
            .where(
              (transaction) =>
                  transaction.parentTransactionId == null &&
                  transaction.businessPurpose ==
                      BusinessPurpose.reimbursementAdvance,
            )
            .map((transaction) => transaction.id)
            .toSet();

    final results = await Future.wait([
      _txRead.aggregateChildren(
        parentIds: refundParentIds,
        purposes: const {BusinessPurpose.refund},
      ),
      _txRead.aggregateChildren(
        parentIds: reimbursementParentIds,
        purposes: const {
          BusinessPurpose.reimbursementReceipt,
          BusinessPurpose.reimbursementClose,
        },
      ),
      _txRead.aggregateChildDetailAmounts(
        parentIds: reimbursementParentIds,
        detailTypes: const {
          TransactionDetailType.reimbursementGapIncome,
          TransactionDetailType.reimbursementGapExpense,
        },
      ),
      _entryRead.findByTransactionIds(pageIds),
      _detailRead.findByTransactionIds(pageIds),
    ]);
    final refundAgg = results[0] as Map<String, TransactionChildAggregate>;
    final reimbursementAgg =
        results[1] as Map<String, TransactionChildAggregate>;
    final gapAgg = results[2] as Map<String, Map<TransactionDetailType, int>>;
    final entriesByTransaction = results[3] as Map<String, List<Entry>>;
    final detailsByTransaction =
        results[4] as Map<String, List<TransactionDetailRecord>>;

    return [
      for (final transaction in page)
        TransactionListReadModel(
          id: transaction.id,
          parentTransactionId: transaction.parentTransactionId,
          businessPurpose: transaction.businessPurpose,
          occurredAt: transaction.occurredAt,
          primaryAmount: transaction.primaryAmount,
          counterpartyName: transaction.counterpartyName,
          note: transaction.note,
          isExcludedFromStats: transaction.isExcludedFromStats,
          isExcludedFromBudget: transaction.isExcludedFromBudget,
          reimbursementExpenseAccountId:
              transaction.reimbursementExpenseAccountId,
          entries: List.unmodifiable(
            entriesByTransaction[transaction.id] ?? const [],
          ),
          details: List.unmodifiable(
            detailsByTransaction[transaction.id] ?? const [],
          ),
          refundedTotal: _aggregateMoney(transaction, refundAgg),
          refundChildCount: _aggregateCount(transaction, refundAgg),
          reimbursementReceivedTotal: _aggregateMoney(
            transaction,
            reimbursementAgg,
          ),
          reimbursementChildCount: _aggregateCount(
            transaction,
            reimbursementAgg,
          ),
          reimbursementGapIncome: _gapMoney(
            transaction,
            gapAgg,
            TransactionDetailType.reimbursementGapIncome,
          ),
          reimbursementGapExpense: _gapMoney(
            transaction,
            gapAgg,
            TransactionDetailType.reimbursementGapExpense,
          ),
        ),
    ];
  }

  Money? _aggregateMoney(
    Transaction transaction,
    Map<String, TransactionChildAggregate> aggregate,
  ) {
    if (transaction.parentTransactionId != null) return null;
    final value = aggregate[transaction.id];
    if (value == null || value.sumMinor == 0) return null;
    return Money(minorUnits: value.sumMinor);
  }

  int _aggregateCount(
    Transaction transaction,
    Map<String, TransactionChildAggregate> aggregate,
  ) {
    if (transaction.parentTransactionId != null) return 0;
    return aggregate[transaction.id]?.count ?? 0;
  }

  Money? _gapMoney(
    Transaction transaction,
    Map<String, Map<TransactionDetailType, int>> aggregate,
    TransactionDetailType type,
  ) {
    if (transaction.parentTransactionId != null ||
        transaction.businessPurpose != BusinessPurpose.reimbursementAdvance) {
      return null;
    }
    final amount = aggregate[transaction.id]?[type] ?? 0;
    return amount == 0 ? null : Money(minorUnits: amount);
  }

  @override
  Stream<CashflowSummary> watchCashflowSummary(CashflowSummaryQuery query) {
    return Stream.fromFuture(_loadCashflowSummary(query)).asBroadcastStream();
  }

  Future<CashflowSummary> _loadCashflowSummary(
    CashflowSummaryQuery query,
  ) async {
    final result = await _metricsSource.aggregateByAccountType(
      accountTypes: const {AccountType.income, AccountType.expense},
      scope: TransactionScopeFilter.stats,
      window: DateTimeWindow(
        from: query.occurredFrom,
        until: query.occurredUntil,
      ),
    );
    return CashflowSummary(
      income: Money(minorUnits: result[AccountType.income] ?? 0),
      expense: Money(minorUnits: result[AccountType.expense] ?? 0),
    );
  }

  @override
  Stream<TransactionDetail?> watchTransactionDetail(String transactionId) {
    return _txRead.watchChanges().asyncMap((_) => _loadDetail(transactionId));
  }

  @override
  Future<TransactionDetail?> findTransactionDetail(String transactionId) {
    return _loadDetail(transactionId);
  }

  @override
  Future<TransactionDetail?> findParentTransactionDetail(
    String parentTransactionId,
  ) {
    return _loadDetail(parentTransactionId);
  }

  @override
  Future<List<TransactionDetail>> findTransactionFacts(
    Set<String> transactionIds,
  ) async {
    if (transactionIds.isEmpty) return const [];
    final transactions = await _txRead.findByIds(transactionIds);
    final fetchedIds =
        transactions.map((transaction) => transaction.id).toSet();
    final entriesByTransaction = await _entryRead.findByTransactionIds(
      fetchedIds,
    );
    final detailsByTransaction = await _detailRead.findByTransactionIds(
      fetchedIds,
    );
    return [
      for (final transaction in transactions)
        TransactionDetail(
          transaction: transaction,
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          entries: List.unmodifiable(
            entriesByTransaction[transaction.id] ?? const [],
          ),
          details: List.unmodifiable(
            detailsByTransaction[transaction.id] ?? const [],
          ),
        ),
    ];
  }

  Future<TransactionDetail?> _loadDetail(String transactionId) async {
    final transaction = await _txRead.findById(transactionId);
    if (transaction == null) return null;
    final entriesByTransaction = await _entryRead.findByTransactionIds({
      transactionId,
    });
    final detailsByTransaction = await _detailRead.findByTransactionIds({
      transactionId,
    });
    final children =
        transaction.parentTransactionId == null
            ? await _txRead.findChildren(parentId: transaction.id)
            : const <Transaction>[];
    final createdAt =
        await _txRead.findCreatedAt(transactionId) ?? transaction.occurredAt;
    final childModels = await _projectListItems(children);
    final refundedTotal =
        (transaction.businessPurpose == BusinessPurpose.dailyExpense ||
                transaction.businessPurpose ==
                    BusinessPurpose.reimbursementAdvance)
            ? await getRefundedTotal(transaction.id)
            : null;
    final reimbursementSummary =
        transaction.businessPurpose == BusinessPurpose.reimbursementAdvance
            ? await getReimbursementSummary(transaction.id)
            : _shouldLoadParentReimbursementSummary(
                  transaction.businessPurpose,
                ) &&
                transaction.parentTransactionId != null
            ? await getReimbursementSummary(transaction.parentTransactionId!)
            : null;
    return TransactionDetail(
      transaction: transaction,
      createdAt: createdAt,
      entries: List.unmodifiable(
        entriesByTransaction[transactionId] ?? const [],
      ),
      details: List.unmodifiable(
        detailsByTransaction[transactionId] ?? const [],
      ),
      children: childModels,
      refundedTotal: refundedTotal,
      reimbursementSummary: reimbursementSummary,
    );
  }

  bool _shouldLoadParentReimbursementSummary(BusinessPurpose purpose) {
    return purpose == BusinessPurpose.refund ||
        purpose == BusinessPurpose.reimbursementReceipt ||
        purpose == BusinessPurpose.reimbursementClose;
  }

  @override
  Future<Transaction?> findTransactionById(String transactionId) {
    return _txRead.findById(transactionId);
  }

  @override
  Future<Money> getRefundedTotal(String parentTransactionId) async {
    final result = await _txRead.aggregateChildren(
      parentIds: {parentTransactionId},
      purposes: const {BusinessPurpose.refund},
    );
    return Money(minorUnits: result[parentTransactionId]?.sumMinor ?? 0);
  }

  @override
  Future<ReimbursementSummary?> getReimbursementSummary(
    String parentTransactionId,
  ) async {
    final advance = await _txRead.findById(parentTransactionId);
    if (advance == null ||
        advance.businessPurpose != BusinessPurpose.reimbursementAdvance) {
      return null;
    }
    final byPurpose = await _txRead.aggregateChildrenByPurpose(
      parentIds: {parentTransactionId},
      purposes: const {
        BusinessPurpose.refund,
        BusinessPurpose.reimbursementReceipt,
        BusinessPurpose.reimbursementClose,
      },
    );
    final bucket = byPurpose[parentTransactionId] ?? const {};
    final refund =
        bucket[BusinessPurpose.refund] ?? TransactionChildAggregate.empty;
    final receipt =
        bucket[BusinessPurpose.reimbursementReceipt] ??
        TransactionChildAggregate.empty;
    final close =
        bucket[BusinessPurpose.reimbursementClose] ??
        TransactionChildAggregate.empty;
    final received = Money(minorUnits: receipt.sumMinor + close.sumMinor);
    final isClosed = close.count > 0;
    return ReimbursementSummary(
      advanceAmount: advance.primaryAmount,
      receivedAmount: received,
      outstanding:
          isClosed
              ? Money.zero()
              : advance.primaryAmount -
                  received -
                  Money(minorUnits: refund.sumMinor),
      isClosed: isClosed,
    );
  }

  @override
  Future<int> getDetailAmountSum({
    required Iterable<String> transactionIds,
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

  @override
  Stream<TransactionCleanupPreview> watchCleanupPreview(
    TransactionCleanupQuery query,
  ) {
    return _txRead.watchCleanupPreview(query);
  }
}
