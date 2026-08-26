import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/entity/entry.dart';
import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/entity/transaction_line.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_rule.dart';
import 'package:smartflow/domain/ledger/valobj/account_usage.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

import '../../account/query/account_query_service.dart';
import '../../metrics/query/port/ledger_metrics_source.dart';
import 'port/entry_read_repository.dart';
import 'port/transaction_line_read_repository.dart';
import 'port/transaction_read_repository.dart';
import 'transaction_queries.dart';
import 'transaction_read_models.dart';
import 'transaction_scope.dart';

abstract interface class TransactionQueryService {
  /// 交易列表订阅同时响应交易事实与账户快照变化：
  /// 分类改名、换图标或调整二级归属后重新规范化查询并重新投影。
  Stream<List<TransactionReadModel>> watchTransactions(
    TransactionListQuery query,
  );

  Future<List<TransactionReadModel>> findTransactions(
    TransactionListQuery query,
  );

  Stream<CashflowSummary> watchCashflowSummary(CashflowSummaryQuery query);

  Stream<TransactionReadModel?> watchTransactionDetail(String transactionId);

  Future<TransactionReadModel?> findTransactionDetail(String transactionId);

  Future<TransactionReadModel?> findParentTransactionDetail(
    String parentTransactionId,
  );

  Future<Transaction?> findTransactionById(String transactionId);

  /// 查询该收支分类最近一笔交易使用的唯一有效结算账户。
  Future<String?> findLastUsedSettlementAccountId(String categoryId);

  Future<int> getLineAmountSum({
    required Iterable<String> transactionIds,
    required TransactionRole role,
  });

  Stream<TransactionCleanupPreview> watchCleanupPreview(
    TransactionCleanupQuery query,
  );
}

class TransactionQueryServiceImpl implements TransactionQueryService {
  const TransactionQueryServiceImpl({
    required TransactionReadRepository transactionRead,
    required EntryReadRepository entryRead,
    required TransactionLineReadRepository lineRead,
    required AccountQueryService accountQuery,
    required LedgerMetricsSource metricsSource,
  }) : _txRead = transactionRead,
       _entryRead = entryRead,
       _lineRead = lineRead,
       _accountQuery = accountQuery,
       _metricsSource = metricsSource;

  final TransactionReadRepository _txRead;
  final EntryReadRepository _entryRead;
  final TransactionLineReadRepository _lineRead;
  final AccountQueryService _accountQuery;
  final LedgerMetricsSource _metricsSource;

  @override
  Stream<List<TransactionReadModel>> watchTransactions(
    TransactionListQuery query,
  ) {
    return _txRead.watchChanges().asyncMap((_) => _loadTransactions(query));
  }

  @override
  Future<List<TransactionReadModel>> findTransactions(
    TransactionListQuery query,
  ) {
    return _loadTransactions(query);
  }

  Future<List<TransactionReadModel>> _loadTransactions(
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
    return _projectTransactions(page, accountsById);
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

  Future<List<TransactionReadModel>> _projectTransactions(
    List<Transaction> transactions,
    Map<String, Account> accountsById,
  ) async {
    if (transactions.isEmpty) return const [];

    final parentIds = {
      for (final transaction in transactions)
        if (transaction.parentTransactionId == null) transaction.id,
    };
    final childrenByParent = await _txRead.findChildrenByParentIds(parentIds);
    final allById = <String, Transaction>{
      for (final transaction in transactions) transaction.id: transaction,
      for (final children in childrenByParent.values)
        for (final child in children) child.id: child,
    };
    final allIds = allById.keys.toSet();
    final results = await Future.wait([
      _entryRead.findByTransactionIds(allIds),
      _lineRead.findByTransactionIds(allIds),
      _txRead.findCreatedAtByIds(allIds),
    ]);
    final entriesByTransaction = results[0] as Map<String, List<Entry>>;
    final linesByTransaction = results[1] as Map<String, List<TransactionLine>>;
    final createdAtByTransaction = results[2] as Map<String, DateTime>;

    TransactionReadModel build(
      Transaction transaction, {
      List<TransactionReadModel> children = const [],
    }) {
      final lines = List<TransactionLine>.of(
        linesByTransaction[transaction.id] ?? const [],
      )..sort((left, right) => left.lineNo.compareTo(right.lineNo));
      return TransactionReadModel(
        id: transaction.id,
        parentTransactionId: transaction.parentTransactionId,
        businessPurpose: transaction.businessPurpose,
        occurredAt: transaction.occurredAt,
        postedAt: transaction.postedAt,
        primaryAmount: transaction.primaryAmount,
        counterpartyName: transaction.counterpartyName,
        note: transaction.note,
        sourceKind: transaction.sourceKind,
        ownership: transaction.ownership,
        isExcludedFromStats: transaction.isExcludedFromStats,
        isExcludedFromBudget: transaction.isExcludedFromBudget,
        createdAt:
            createdAtByTransaction[transaction.id] ?? transaction.occurredAt,
        lines: lines,
        impactsByAccountId: _accountImpacts(
          entriesByTransaction[transaction.id] ?? const [],
          accountsById,
        ),
        children: children,
      );
    }

    final childModelsByParent = <String, List<TransactionReadModel>>{
      for (final entry in childrenByParent.entries)
        entry.key: [for (final child in entry.value) build(child)],
    };
    return [
      for (final transaction in transactions)
        build(
          transaction,
          children: childModelsByParent[transaction.id] ?? const [],
        ),
    ];
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
      final amounts = entry.direction == EntryDirection.debit
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
  Stream<TransactionReadModel?> watchTransactionDetail(String transactionId) {
    return _txRead.watchChanges().asyncMap((_) => _loadDetail(transactionId));
  }

  @override
  Future<TransactionReadModel?> findTransactionDetail(String transactionId) {
    return _loadDetail(transactionId);
  }

  @override
  Future<TransactionReadModel?> findParentTransactionDetail(
    String parentTransactionId,
  ) {
    return _loadDetail(parentTransactionId);
  }

  Future<TransactionReadModel?> _loadDetail(String transactionId) async {
    final transaction = await _txRead.findById(transactionId);
    if (transaction == null) return null;
    final models = await _projectTransactions([
      transaction,
    ], await _accountQuery.findAccountsById());
    return models.single;
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
    final linesByTransaction = await _lineRead.findByTransactionIds({
      transaction.id,
    });
    final candidates = <String>{};
    for (final line in linesByTransaction[transaction.id] ?? const []) {
      if (line.role != TransactionRole.settlementIn &&
          line.role != TransactionRole.settlementOut) {
        continue;
      }
      final accountId = line.accountId;
      if (accountId == null) continue;
      final account = accountsById[accountId];
      if (account != null &&
          account.type.isUserAccount &&
          accountMatchesUsage(account, AccountUsage.settlement)) {
        candidates.add(account.id);
      }
    }
    return candidates.length == 1 ? candidates.single : null;
  }

  @override
  Future<int> getLineAmountSum({
    required Iterable<String> transactionIds,
    required TransactionRole role,
  }) async {
    final ids = transactionIds.toSet();
    if (ids.isEmpty) return 0;
    final result = await _lineRead.sumOwnByRole(
      transactionIds: ids,
      roles: {role},
    );
    var total = 0;
    for (final byRole in result.values) {
      total += byRole[role] ?? 0;
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
