import 'package:drift/drift.dart';
import 'package:smartflow/core/time/month_key.dart';

import '../../../domain/ledger/valobj/ledger_enum.dart';
import '../../../application/ledger/ledger_query_port_api.dart';
import '../../database/app_database.dart';
import '../sql/balance_expressions.dart';

class DriftLedgerMetricsSource implements LedgerMetricsSource {
  const DriftLedgerMetricsSource(this._db);

  final AppDatabase _db;

  /// 归档账户不参与任何统计口径；有交易引用的分类不可删除，
  /// 因此分录只会指向活跃分类。
  Expression<bool> _statisticalAccountFilter() {
    return _db.accounts.archivedAt.isNull();
  }

  @override
  Future<List<AccountAggregate>> aggregateByAccount({
    required Set<AccountType> accountTypes,
    required TransactionScopeFilter scope,
    DateTimeWindow window = const DateTimeWindow(),
  }) async {
    if (accountTypes.isEmpty) return const [];

    final accountIdCol = _db.accounts.id;
    final typeCol = _db.accounts.accountType;
    final sumExpr =
        balanceDeltaExpr(entries: _db.entries, accounts: _db.accounts).sum();
    final select =
        _db.selectOnly(_db.entries).join([
            innerJoin(
              _db.transactions,
              _db.transactions.id.equalsExp(_db.entries.transactionId),
            ),
            innerJoin(
              _db.accounts,
              _db.accounts.id.equalsExp(_db.entries.accountId),
            ),
          ])
          ..addColumns([accountIdCol, typeCol, sumExpr])
          ..where(
            applyTransactionScope(transactions: _db.transactions, scope: scope),
          )
          ..where(_statisticalAccountFilter())
          ..where(_db.accounts.accountType.isInValues(accountTypes))
          ..groupBy([accountIdCol, typeCol]);

    if (window.from != null) {
      select.where(
        _db.transactions.occurredAt.isBiggerOrEqualValue(window.from!),
      );
    }
    if (window.until != null) {
      select.where(
        _db.transactions.occurredAt.isSmallerThanValue(window.until!),
      );
    }

    return [
      for (final row in await select.get())
        if (row.read(accountIdCol) case final String accountId)
          if (row.read(typeCol) case final String typeName)
            AccountAggregate(
              accountId: accountId,
              accountType: AccountType.values.byName(typeName),
              amountMinor: row.read(sumExpr) ?? 0,
            ),
    ];
  }

  @override
  Future<List<TagAggregate>> aggregateByTag({
    required Set<AccountType> accountTypes,
    required TransactionScopeFilter scope,
    DateTimeWindow window = const DateTimeWindow(),
  }) async {
    if (accountTypes.isEmpty) return const [];

    final tagIdCol = _db.transactionTags.tagId;
    final typeCol = _db.accounts.accountType;
    final sumExpr =
        balanceDeltaExpr(entries: _db.entries, accounts: _db.accounts).sum();
    final groupRoot = coalesce<String>([
      _db.transactions.parentTransactionId,
      _db.transactions.id,
    ]);
    final select =
        _db.selectOnly(_db.entries).join([
            innerJoin(
              _db.transactions,
              _db.transactions.id.equalsExp(_db.entries.transactionId),
            ),
            innerJoin(
              _db.accounts,
              _db.accounts.id.equalsExp(_db.entries.accountId),
            ),
            leftOuterJoin(
              _db.transactionTags,
              _db.transactionTags.transactionId.equalsExp(groupRoot),
            ),
          ])
          ..addColumns([tagIdCol, typeCol, sumExpr])
          ..where(
            applyTransactionScope(transactions: _db.transactions, scope: scope),
          )
          ..where(_statisticalAccountFilter())
          ..where(_db.accounts.accountType.isInValues(accountTypes))
          ..groupBy([tagIdCol, typeCol]);

    if (window.from != null) {
      select.where(
        _db.transactions.occurredAt.isBiggerOrEqualValue(window.from!),
      );
    }
    if (window.until != null) {
      select.where(
        _db.transactions.occurredAt.isSmallerThanValue(window.until!),
      );
    }

    return [
      for (final row in await select.get())
        if (row.read(typeCol) case final String typeName)
          TagAggregate(
            tagId: row.read(tagIdCol),
            accountType: AccountType.values.byName(typeName),
            amountMinor: row.read(sumExpr) ?? 0,
          ),
    ];
  }

  @override
  Future<Map<AccountType, int>> aggregateByAccountType({
    required Set<AccountType> accountTypes,
    required TransactionScopeFilter scope,
    DateTimeWindow window = const DateTimeWindow(),
  }) async {
    if (accountTypes.isEmpty) return const {};

    final deltaExpr = balanceDeltaExpr(
      entries: _db.entries,
      accounts: _db.accounts,
    );
    final sumExpr = deltaExpr.sum();
    final typeCol = _db.accounts.accountType;

    final select =
        _db.selectOnly(_db.entries).join([
            innerJoin(
              _db.transactions,
              _db.transactions.id.equalsExp(_db.entries.transactionId),
            ),
            innerJoin(
              _db.accounts,
              _db.accounts.id.equalsExp(_db.entries.accountId),
            ),
          ])
          ..addColumns([typeCol, sumExpr])
          ..where(
            applyTransactionScope(transactions: _db.transactions, scope: scope),
          )
          ..where(_statisticalAccountFilter())
          ..where(_db.accounts.accountType.isInValues(accountTypes))
          ..groupBy([typeCol]);

    if (window.from != null) {
      select.where(
        _db.transactions.occurredAt.isBiggerOrEqualValue(window.from!),
      );
    }
    if (window.until != null) {
      select.where(
        _db.transactions.occurredAt.isSmallerThanValue(window.until!),
      );
    }

    final rows = await select.get();
    final result = <AccountType, int>{};
    for (final row in rows) {
      final typeName = row.read(typeCol);
      final sum = row.read(sumExpr);
      if (typeName == null) continue;
      final type = AccountType.values.byName(typeName);
      result[type] = sum ?? 0;
    }
    return result;
  }

  @override
  Future<Map<DateTime, Map<AccountType, int>>> aggregateByAccountTypeByDay({
    required Set<AccountType> accountTypes,
    required TransactionScopeFilter scope,
    DateTimeWindow window = const DateTimeWindow(),
  }) async {
    if (accountTypes.isEmpty) return const {};

    final occurredAtCol = _db.transactions.occurredAt;
    final typeCol = _db.accounts.accountType;
    final sumExpr =
        balanceDeltaExpr(entries: _db.entries, accounts: _db.accounts).sum();

    final select =
        _db.selectOnly(_db.entries).join([
            innerJoin(
              _db.transactions,
              _db.transactions.id.equalsExp(_db.entries.transactionId),
            ),
            innerJoin(
              _db.accounts,
              _db.accounts.id.equalsExp(_db.entries.accountId),
            ),
          ])
          ..addColumns([occurredAtCol, typeCol, sumExpr])
          ..where(
            applyTransactionScope(transactions: _db.transactions, scope: scope),
          )
          ..where(_statisticalAccountFilter())
          ..where(_db.accounts.accountType.isInValues(accountTypes))
          ..groupBy([occurredAtCol, typeCol]);

    if (window.from != null) {
      select.where(
        _db.transactions.occurredAt.isBiggerOrEqualValue(window.from!),
      );
    }
    if (window.until != null) {
      select.where(
        _db.transactions.occurredAt.isSmallerThanValue(window.until!),
      );
    }

    final rows = await select.get();
    final result = <DateTime, Map<AccountType, int>>{};
    for (final row in rows) {
      final occurredAt = row.read(occurredAtCol);
      final typeName = row.read(typeCol);
      final sum = row.read(sumExpr) ?? 0;
      if (occurredAt == null || typeName == null) continue;
      final date = DateTime(occurredAt.year, occurredAt.month, occurredAt.day);
      final type = AccountType.values.byName(typeName);
      final dayMap = result.putIfAbsent(date, () => <AccountType, int>{});
      dayMap.update(type, (v) => v + sum, ifAbsent: () => sum);
    }
    return result;
  }

  @override
  Future<Map<MonthKey, Map<AccountType, int>>> aggregateByAccountTypeByMonth({
    required Set<AccountType> accountTypes,
    required TransactionScopeFilter scope,
    required DateTimeWindow window,
  }) async {
    if (accountTypes.isEmpty) return const {};
    final buckets = _monthBuckets(window);
    if (buckets.isEmpty) return const {};

    final occurredAtCol = _db.transactions.occurredAt;
    final monthExpr = CaseWhenExpression<int>(
      cases: [
        for (final bucket in buckets)
          CaseWhen(
            occurredAtCol.isBiggerOrEqualValue(bucket.from) &
                occurredAtCol.isSmallerThanValue(bucket.until),
            then: Constant(bucket.key.year * 100 + bucket.key.month),
          ),
      ],
      orElse: const Constant(0),
    );
    final typeCol = _db.accounts.accountType;
    final sumExpr =
        balanceDeltaExpr(entries: _db.entries, accounts: _db.accounts).sum();
    final select =
        _db.selectOnly(_db.entries).join([
            innerJoin(
              _db.transactions,
              _db.transactions.id.equalsExp(_db.entries.transactionId),
            ),
            innerJoin(
              _db.accounts,
              _db.accounts.id.equalsExp(_db.entries.accountId),
            ),
          ])
          ..addColumns([monthExpr, typeCol, sumExpr])
          ..where(
            applyTransactionScope(transactions: _db.transactions, scope: scope),
          )
          ..where(_statisticalAccountFilter())
          ..where(_db.accounts.accountType.isInValues(accountTypes))
          ..groupBy([monthExpr, typeCol]);

    if (window.from != null) {
      select.where(
        _db.transactions.occurredAt.isBiggerOrEqualValue(window.from!),
      );
    }
    if (window.until != null) {
      select.where(
        _db.transactions.occurredAt.isSmallerThanValue(window.until!),
      );
    }

    final result = <MonthKey, Map<AccountType, int>>{};
    for (final row in await select.get()) {
      final encodedMonth = row.read(monthExpr);
      final typeName = row.read(typeCol);
      if (encodedMonth == null || encodedMonth == 0 || typeName == null) {
        continue;
      }
      final month = MonthKey(
        year: encodedMonth ~/ 100,
        month: encodedMonth % 100,
      );
      final type = AccountType.values.byName(typeName);
      final amount = row.read(sumExpr) ?? 0;
      final monthMap = result.putIfAbsent(month, () => <AccountType, int>{});
      monthMap.update(type, (value) => value + amount, ifAbsent: () => amount);
    }
    return result;
  }

  @override
  Stream<void> watchChanges() async* {
    yield null;
    await for (final _ in _db.tableUpdates(
      TableUpdateQuery.onAllTables([
        _db.transactions,
        _db.entries,
        _db.accounts,
      ]),
    )) {
      yield null;
    }
  }
}

List<_MonthBucket> _monthBuckets(DateTimeWindow window) {
  final from = window.from;
  final until = window.until;
  if (from == null || until == null || !from.isBefore(until)) return const [];

  final lastIncluded = until.subtract(const Duration(microseconds: 1));
  final result = <_MonthBucket>[];
  var month = MonthKey.fromDate(from);
  final lastMonth = MonthKey.fromDate(lastIncluded);
  while (month.compareTo(lastMonth) <= 0) {
    final bucketFrom = month.start.isAfter(from) ? month.start : from;
    final bucketUntil =
        month.nextMonthStart.isBefore(until) ? month.nextMonthStart : until;
    result.add(_MonthBucket(key: month, from: bucketFrom, until: bucketUntil));
    month = MonthKey.fromDate(month.nextMonthStart);
  }
  return result;
}

class _MonthBucket {
  const _MonthBucket({
    required this.key,
    required this.from,
    required this.until,
  });

  final MonthKey key;
  final DateTime from;
  final DateTime until;
}
