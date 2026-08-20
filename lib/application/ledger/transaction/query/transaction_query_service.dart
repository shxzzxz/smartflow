import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/entity/entry.dart';
import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/entity/transaction_detail_record.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_rule.dart';
import 'package:smartflow/domain/ledger/valobj/account_usage.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

import '../../account/query/account_query_service.dart';
import '../../metrics/query/port/ledger_metrics_source.dart';
import 'port/entry_read_repository.dart';
import 'port/transaction_detail_read_repository.dart';
import 'port/transaction_read_repository.dart';
import 'transaction_queries.dart';
import 'transaction_read_models.dart';
import 'transaction_scope.dart';

abstract interface class TransactionQueryService {
  /// 交易列表订阅同时响应交易事实与账户快照变化：
  /// 分类改名、换图标或调整二级归属后重新规范化查询并重新投影。
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

  /// 查询该收支分类最近一笔交易使用的唯一有效结算账户。
  Future<String?> findLastUsedSettlementAccountId(String categoryId);

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
    required AccountQueryService accountQuery,
    required LedgerMetricsSource metricsSource,
  }) : _txRead = transactionRead,
       _entryRead = entryRead,
       _detailRead = detailRead,
       _accountQuery = accountQuery,
       _metricsSource = metricsSource;

  final TransactionReadRepository _txRead;
  final EntryReadRepository _entryRead;
  final TransactionDetailReadRepository _detailRead;
  final AccountQueryService _accountQuery;
  final LedgerMetricsSource _metricsSource;

  @override
  Stream<List<TransactionListReadModel>> watchTransactions(
    TransactionListQuery query,
  ) {
    return _txRead.watchChanges().asyncMap((_) => _loadTransactions(query));
  }

  @override
  Future<List<TransactionListReadModel>> findTransactions(
    TransactionListQuery query,
  ) {
    return _loadTransactions(query);
  }

  Future<List<TransactionListReadModel>> _loadTransactions(
    TransactionListQuery query,
  ) async {
    final accountsById = await _accountQuery.findAccountsById();
    final pageQuery = _normalizeQuery(query, accountsById);
    final categoryAccountIds = pageQuery.categoryAccountIds;
    final settlementAccountIds = pageQuery.settlementAccountIds;
    final tagIds = pageQuery.tagIds;
    if ((categoryAccountIds != null && categoryAccountIds.isEmpty) ||
        (settlementAccountIds != null && settlementAccountIds.isEmpty) ||
        (tagIds != null && tagIds.isEmpty)) {
      return const [];
    }
    final page = await _txRead.watchPage(pageQuery).first;
    return _projectListItems(page, accountsById);
  }

  TransactionPageQuery _normalizeQuery(
    TransactionListQuery query,
    Map<String, Account> accountsById,
  ) {
    return TransactionPageQuery(
      categoryAccountIds: _expandCategoryFilter(query, accountsById),
      settlementAccountIds: _validateSettlementAccountFilter(
        query.settlementAccountIds,
        accountsById,
      ),
      occurredFrom: query.occurredFrom,
      occurredUntil: query.occurredUntil,
      topLevelOnly: query.topLevelOnly,
      limit: query.limit,
      offset: query.offset,
      before: query.before,
      scope: query.scope,
      tagIds: query.tagIds,
      untaggedOnly: query.untaggedOnly,
    );
  }

  /// 结算账户只能是当前活跃的 asset / liability 用户账户。
  /// 不存在、归档或系统账户返回空集合，表达“无可匹配项”。
  Set<String>? _validateSettlementAccountFilter(
    Set<String>? accountIds,
    Map<String, Account> accountsById,
  ) {
    if (accountIds == null) return null;
    return {
      for (final accountId in accountIds)
        if (accountsById[accountId] case final account?
            when account.type.isUserAccount && !account.isArchived)
          account.id,
    };
  }

  /// 只保留当前账户快照中的活跃收入/支出分类。
  Set<String>? _expandCategoryFilter(
    TransactionListQuery query,
    Map<String, Account> accountsById,
  ) {
    final accountIds = query.categoryAccountIds;
    if (accountIds == null) return null;
    return {
      for (final accountId in accountIds)
        if (accountsById[accountId] case final account?
            when account.type.isCategory && !account.isArchived)
          account.id,
    };
  }

  Future<List<TransactionListReadModel>> _projectListItems(
    List<Transaction> page,
    Map<String, Account> accountsById,
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
    final detailTransactionIds =
        page
            .where(
              (transaction) =>
                  transaction.businessPurpose ==
                      BusinessPurpose.debtRepayment ||
                  transaction.businessPurpose ==
                      BusinessPurpose.receivableCollection,
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
      _detailRead.findByTransactionIds(detailTransactionIds),
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
          businessPurpose: transaction.businessPurpose,
          occurredAt: transaction.occurredAt,
          primaryAmount: transaction.primaryAmount,
          isExcludedFromStats: transaction.isExcludedFromStats,
          isExcludedFromBudget: transaction.isExcludedFromBudget,
          primaryCategoryId: _primaryCategoryId(
            transaction,
            entriesByTransaction[transaction.id] ?? const [],
            accountsById,
          ),
          impactsByAccountId: _accountImpacts(
            entriesByTransaction[transaction.id] ?? const [],
            accountsById,
          ),
          adjustments: _adjustments(
            transaction: transaction,
            details: detailsByTransaction[transaction.id] ?? const [],
            refundAgg: refundAgg,
            reimbursementAgg: reimbursementAgg,
            gapAgg: gapAgg,
          ),
        ),
    ];
  }

  String? _primaryCategoryId(
    Transaction transaction,
    List<Entry> entries,
    Map<String, Account> accountsById,
  ) {
    final reimbursementCategoryId = transaction.reimbursementExpenseAccountId;
    final category = switch (transaction.businessPurpose) {
      BusinessPurpose.dailyExpense => _uniqueRoleAccount(
        entries,
        accountsById,
        type: AccountType.expense,
        direction: EntryDirection.debit,
        amount: transaction.primaryAmount,
      ),
      BusinessPurpose.dailyIncome => _uniqueRoleAccount(
        entries,
        accountsById,
        type: AccountType.income,
        direction: EntryDirection.credit,
        amount: transaction.primaryAmount,
      ),
      BusinessPurpose.reimbursementAdvance =>
        reimbursementCategoryId == null
            ? null
            : accountsById[reimbursementCategoryId],
      BusinessPurpose.badDebt => _uniqueRoleAccount(
        entries,
        accountsById,
        type: AccountType.expense,
        direction: EntryDirection.debit,
        amount: transaction.primaryAmount,
      ),
      BusinessPurpose.debtRelief => _uniqueRoleAccount(
        entries,
        accountsById,
        type: AccountType.income,
        direction: EntryDirection.credit,
        amount: transaction.primaryAmount,
      ),
      BusinessPurpose.receivableCollection => _firstRoleAccount(
        entries,
        accountsById,
        type: AccountType.income,
        direction: EntryDirection.credit,
      ),
      _ => null,
    };
    return category?.id;
  }

  Account? _firstRoleAccount(
    List<Entry> entries,
    Map<String, Account> accountsById, {
    required AccountType type,
    required EntryDirection direction,
  }) {
    for (final entry in entries) {
      final account = accountsById[entry.accountId];
      if (account?.type == type && entry.direction == direction) return account;
    }
    return null;
  }

  Account? _uniqueRoleAccount(
    List<Entry> entries,
    Map<String, Account> accountsById, {
    required AccountType type,
    required EntryDirection direction,
    required Money amount,
  }) {
    Account? candidate;
    for (final entry in entries) {
      final account = accountsById[entry.accountId];
      if (account?.type != type ||
          entry.direction != direction ||
          entry.amount.minorUnits != amount.minorUnits) {
        continue;
      }
      if (candidate != null) return null;
      candidate = account;
    }
    return candidate;
  }

  Map<String, TransactionAccountImpact> _accountImpacts(
    List<Entry> entries,
    Map<String, Account> accountsById,
  ) {
    final debitByAccountId = <String, int>{};
    final creditByAccountId = <String, int>{};
    for (final entry in entries) {
      final account = accountsById[entry.accountId];
      if (account == null) continue;
      final amounts =
          entry.direction == EntryDirection.debit
              ? debitByAccountId
              : creditByAccountId;
      amounts[entry.accountId] =
          (amounts[entry.accountId] ?? 0) + entry.amount.minorUnits;
    }
    final accountIds = {...debitByAccountId.keys, ...creditByAccountId.keys};
    return Map.unmodifiable({
      for (final accountId in accountIds)
        if (accountsById[accountId] case final account?)
          accountId: TransactionAccountImpact(
            debitAmount: Money(minorUnits: debitByAccountId[accountId] ?? 0),
            creditAmount: Money(minorUnits: creditByAccountId[accountId] ?? 0),
            netChange: Money(
              minorUnits:
                  balanceDeltaMinor(
                    accountType: account.type,
                    direction: EntryDirection.debit,
                    amountMinor: debitByAccountId[accountId] ?? 0,
                  ) +
                  balanceDeltaMinor(
                    accountType: account.type,
                    direction: EntryDirection.credit,
                    amountMinor: creditByAccountId[accountId] ?? 0,
                  ),
            ),
          ),
    });
  }

  List<TransactionAdjustment> _adjustments({
    required Transaction transaction,
    required List<TransactionDetailRecord> details,
    required Map<String, TransactionChildAggregate> refundAgg,
    required Map<String, TransactionChildAggregate> reimbursementAgg,
    required Map<String, Map<TransactionDetailType, int>> gapAgg,
  }) {
    if (transaction.parentTransactionId != null) return const [];
    final adjustments = <TransactionAdjustment>[];
    void add(TransactionAdjustmentKind kind, int amountMinor) {
      if (amountMinor <= 0) return;
      adjustments.add(
        TransactionAdjustment(
          kind: kind,
          amount: Money(minorUnits: amountMinor),
        ),
      );
    }

    switch (transaction.businessPurpose) {
      case BusinessPurpose.dailyExpense:
        add(
          TransactionAdjustmentKind.refund,
          refundAgg[transaction.id]?.sumMinor ?? 0,
        );
      case BusinessPurpose.reimbursementAdvance:
        add(
          TransactionAdjustmentKind.refund,
          refundAgg[transaction.id]?.sumMinor ?? 0,
        );
        add(
          TransactionAdjustmentKind.reimbursementReceived,
          reimbursementAgg[transaction.id]?.sumMinor ?? 0,
        );
        add(
          TransactionAdjustmentKind.reimbursementGapIncome,
          gapAgg[transaction.id]?[TransactionDetailType
                  .reimbursementGapIncome] ??
              0,
        );
        add(
          TransactionAdjustmentKind.reimbursementGapExpense,
          gapAgg[transaction.id]?[TransactionDetailType
                  .reimbursementGapExpense] ??
              0,
        );
      case BusinessPurpose.debtRepayment:
        add(
          TransactionAdjustmentKind.repaymentInterest,
          _detailAmount(details, TransactionDetailType.repaymentInterest),
        );
        add(
          TransactionAdjustmentKind.repaymentFee,
          _detailAmount(details, TransactionDetailType.repaymentFee),
        );
        add(
          TransactionAdjustmentKind.repaymentDiscount,
          _detailAmount(details, TransactionDetailType.repaymentDiscount),
        );
      case BusinessPurpose.receivableCollection:
        add(
          TransactionAdjustmentKind.receivableCollectionPrincipal,
          _detailAmount(
            details,
            TransactionDetailType.receivableCollectionPrincipal,
          ),
        );
        add(
          TransactionAdjustmentKind.receivableCollectionInterest,
          _detailAmount(
            details,
            TransactionDetailType.receivableCollectionInterest,
          ),
        );
      default:
        break;
    }
    return List.unmodifiable(adjustments);
  }

  int _detailAmount(
    List<TransactionDetailRecord> details,
    TransactionDetailType type,
  ) {
    var total = 0;
    for (final detail in details) {
      if (detail.type == type) total += detail.amount.minorUnits;
    }
    return total;
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
    final childModels =
        children.isEmpty
            ? const <TransactionListReadModel>[]
            : await _projectListItems(
              children,
              await _accountQuery.findAccountsById(),
            );
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
  Future<String?> findLastUsedSettlementAccountId(String categoryId) async {
    final accountsById = await _accountQuery.findAccountsById();
    final category = accountsById[categoryId];
    if (category == null || !category.type.isCategory || category.isArchived) {
      return null;
    }
    final transaction = await _txRead.findLatestByCategory(
      CategoryTransactionQuery(
        categoryId: categoryId,
        hierarchy: TransactionHierarchyFilter.topLevel,
      ),
    );
    if (transaction == null) return null;
    final entriesByTransaction = await _entryRead.findByTransactionIds({
      transaction.id,
    });
    final accountIds =
        entriesByTransaction[transaction.id]
            ?.map((entry) => entry.accountId)
            .toSet() ??
        const <String>{};
    final candidates = {
      for (final accountId in accountIds)
        if (accountsById[accountId] case final account?
            when account.type.isUserAccount &&
                accountMatchesUsage(account, AccountUsage.settlement))
          account.id,
    };
    return candidates.length == 1 ? candidates.single : null;
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
