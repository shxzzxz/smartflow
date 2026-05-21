import 'package:drift/drift.dart';

import '../../../core/money/money.dart';
import '../../../core/time/month_key.dart';
import '../../../domain/accounting/queries/financial_metrics_queries.dart';
import '../../../domain/accounting/repositories/financial_metrics_repository.dart';
import '../../../domain/accounting/views/financial_metrics_views.dart';
import '../../../domain/accounting/views/transaction_views.dart';
import '../../app_database.dart';

class DriftFinancialMetricsRepository implements FinancialMetricsRepository {
  const DriftFinancialMetricsRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<CashflowComparison> watchCashflowComparison(
    CashflowComparisonQuery query,
  ) {
    final currentStart = query.month.start;
    final previousMonth = _previousMonth(query.month);
    final previousStart = previousMonth.start;
    final isCurrentMonth =
        query.asOfDate != null &&
        query.asOfDate!.year == query.month.year &&
        query.asOfDate!.month == query.month.month;
    final currentUntil =
        isCurrentMonth
            ? DateTime(
              query.month.year,
              query.month.month,
              query.asOfDate!.day + 1,
            )
            : query.month.nextMonthStart;
    final previousSamePeriodUntil =
        isCurrentMonth
            ? _samePeriodUntil(previousMonth, query.asOfDate!.day)
            : query.month.start;

    return _database
        .customSelect(
          'SELECT '
          "COALESCE(SUM(CASE WHEN t.occurred_at >= ? "
          'AND t.occurred_at < ? '
          "AND a.account_type = 'income' THEN "
          "CASE WHEN e.direction = 'credit' THEN e.amount_minor "
          "WHEN e.direction = 'debit' THEN -e.amount_minor "
          'ELSE 0 END ELSE 0 END), 0) AS current_income_minor, '
          "COALESCE(SUM(CASE WHEN t.occurred_at >= ? "
          'AND t.occurred_at < ? '
          "AND a.account_type = 'expense' THEN "
          "CASE WHEN e.direction = 'debit' THEN e.amount_minor "
          "WHEN e.direction = 'credit' THEN -e.amount_minor "
          'ELSE 0 END ELSE 0 END), 0) AS current_expense_minor, '
          "COALESCE(SUM(CASE WHEN t.occurred_at >= ? "
          'AND t.occurred_at < ? '
          "AND a.account_type = 'income' THEN "
          "CASE WHEN e.direction = 'credit' THEN e.amount_minor "
          "WHEN e.direction = 'debit' THEN -e.amount_minor "
          'ELSE 0 END ELSE 0 END), 0) AS previous_same_income_minor, '
          "COALESCE(SUM(CASE WHEN t.occurred_at >= ? "
          'AND t.occurred_at < ? '
          "AND a.account_type = 'expense' THEN "
          "CASE WHEN e.direction = 'debit' THEN e.amount_minor "
          "WHEN e.direction = 'credit' THEN -e.amount_minor "
          'ELSE 0 END ELSE 0 END), 0) AS previous_same_expense_minor, '
          "COALESCE(SUM(CASE WHEN t.occurred_at >= ? "
          'AND t.occurred_at < ? '
          "AND a.account_type = 'income' THEN "
          "CASE WHEN e.direction = 'credit' THEN e.amount_minor "
          "WHEN e.direction = 'debit' THEN -e.amount_minor "
          'ELSE 0 END ELSE 0 END), 0) AS previous_full_income_minor, '
          "COALESCE(SUM(CASE WHEN t.occurred_at >= ? "
          'AND t.occurred_at < ? '
          "AND a.account_type = 'expense' THEN "
          "CASE WHEN e.direction = 'debit' THEN e.amount_minor "
          "WHEN e.direction = 'credit' THEN -e.amount_minor "
          'ELSE 0 END ELSE 0 END), 0) AS previous_full_expense_minor '
          'FROM entries e '
          'JOIN transactions t ON t.id = e.transaction_id '
          'JOIN accounts a ON a.id = e.account_id '
          "WHERE t.business_state = 'current' "
          'AND t.is_excluded_from_stats = 0 '
          'AND t.currency_code = ? '
          'AND t.occurred_at >= ? '
          'AND t.occurred_at < ? '
          "AND a.account_type IN ('income', 'expense')",
          variables: [
            Variable<DateTime>(currentStart),
            Variable<DateTime>(currentUntil),
            Variable<DateTime>(currentStart),
            Variable<DateTime>(currentUntil),
            Variable<DateTime>(previousStart),
            Variable<DateTime>(previousSamePeriodUntil),
            Variable<DateTime>(previousStart),
            Variable<DateTime>(previousSamePeriodUntil),
            Variable<DateTime>(previousStart),
            Variable<DateTime>(currentStart),
            Variable<DateTime>(previousStart),
            Variable<DateTime>(currentStart),
            Variable<String>(query.currencyCode),
            Variable<DateTime>(previousStart),
            Variable<DateTime>(currentUntil),
          ],
          readsFrom: {
            _database.transactions,
            _database.entries,
            _database.accounts,
          },
        )
        .watchSingle()
        .map((row) {
          Money money(String column) {
            return Money(
              minorUnits: row.read<int>(column),
              currency: query.currencyCode,
            );
          }

          return CashflowComparison(
            current: CashflowSummary(
              income: money('current_income_minor'),
              expense: money('current_expense_minor'),
            ),
            previousSamePeriod: CashflowSummary(
              income: money('previous_same_income_minor'),
              expense: money('previous_same_expense_minor'),
            ),
            previousFullPeriod: CashflowSummary(
              income: money('previous_full_income_minor'),
              expense: money('previous_full_expense_minor'),
            ),
          );
        });
  }

  @override
  Stream<List<DailyCashflowSummary>> watchDailyCashflowSummaries(
    DailyCashflowSummaryQuery query,
  ) {
    return _database
        .customSelect(
          'SELECT t.occurred_at, a.account_type, e.direction, e.amount_minor '
          'FROM entries e '
          'JOIN transactions t ON t.id = e.transaction_id '
          'JOIN accounts a ON a.id = e.account_id '
          "WHERE t.business_state = 'current' "
          'AND t.is_excluded_from_stats = 0 '
          'AND t.currency_code = ? '
          'AND t.occurred_at >= ? '
          'AND t.occurred_at < ? '
          "AND a.account_type IN ('income', 'expense')",
          variables: [
            Variable<String>(query.currencyCode),
            Variable<DateTime>(query.month.start),
            Variable<DateTime>(query.month.nextMonthStart),
          ],
          readsFrom: {
            _database.transactions,
            _database.entries,
            _database.accounts,
          },
        )
        .watch()
        .map((rows) {
          final totals = <DateTime, _DailyTotals>{};
          for (final row in rows) {
            final occurredAt = row.read<DateTime>('occurred_at');
            final date = DateTime(
              occurredAt.year,
              occurredAt.month,
              occurredAt.day,
            );
            final total = totals.putIfAbsent(date, _DailyTotals.new);
            final accountType = row.read<String>('account_type');
            final direction = row.read<String>('direction');
            final amountMinor = row.read<int>('amount_minor');
            if (accountType == 'income') {
              total.incomeMinor +=
                  direction == 'credit' ? amountMinor : -amountMinor;
            } else if (accountType == 'expense') {
              total.expenseMinor +=
                  direction == 'debit' ? amountMinor : -amountMinor;
            }
          }

          final dates = totals.keys.toList()..sort();
          return [
            for (final date in dates)
              DailyCashflowSummary(
                date: date,
                income: Money(
                  minorUnits: totals[date]!.incomeMinor,
                  currency: query.currencyCode,
                ),
                expense: Money(
                  minorUnits: totals[date]!.expenseMinor,
                  currency: query.currencyCode,
                ),
              ),
          ];
        });
  }

  @override
  Stream<BalanceSheetComparison> watchBalanceSheetComparison(
    BalanceSheetComparisonQuery query,
  ) {
    final currentCutoff = query.asOfExclusive ?? query.month.nextMonthStart;
    final previousCutoff = query.month.start;
    final balanceSelect = [
      _balanceExpression('current_assets_minor', 'asset', '< ?'),
      _balanceExpression('current_liabilities_minor', 'liability', '< ?'),
      _balanceExpression('previous_assets_minor', 'asset', '< ?'),
      _balanceExpression('previous_liabilities_minor', 'liability', '< ?'),
    ].join(', ');

    return _database
        .customSelect(
          'SELECT $balanceSelect '
          'FROM entries e '
          'JOIN transactions t ON t.id = e.transaction_id '
          'JOIN accounts a ON a.id = e.account_id '
          "WHERE t.business_state = 'current' "
          'AND t.currency_code = ? '
          "AND a.account_type IN ('asset', 'liability')",
          variables: [
            Variable<DateTime>(currentCutoff),
            Variable<DateTime>(currentCutoff),
            Variable<DateTime>(previousCutoff),
            Variable<DateTime>(previousCutoff),
            Variable<String>(query.currencyCode),
          ],
          readsFrom: {
            _database.transactions,
            _database.entries,
            _database.accounts,
          },
        )
        .watchSingle()
        .map(
          (row) => BalanceSheetComparison(
            current: _snapshot(
              row,
              assetsColumn: 'current_assets_minor',
              liabilitiesColumn: 'current_liabilities_minor',
              currencyCode: query.currencyCode,
            ),
            previous: _snapshot(
              row,
              assetsColumn: 'previous_assets_minor',
              liabilitiesColumn: 'previous_liabilities_minor',
              currencyCode: query.currencyCode,
            ),
          ),
        );
  }

  @override
  Stream<List<NetAssetTrendPoint>> watchNetAssetTrend(
    NetAssetTrendQuery query,
  ) {
    final months = _trendMonths(query.endMonth, query.months);
    if (months.isEmpty) {
      return Stream.value(const []);
    }

    final selects = <String>[];
    final variables = <Variable<Object>>[];
    for (var i = 0; i < months.length; i++) {
      final month = months[i];
      final cutoff =
          i == months.length - 1 && query.currentAsOfExclusive != null
              ? query.currentAsOfExclusive!
              : month.nextMonthStart;
      selects.add(
        "COALESCE(SUM(CASE WHEN t.occurred_at < ? THEN CASE "
        "WHEN a.account_type = 'asset' AND e.direction = 'debit' "
        'THEN e.amount_minor '
        "WHEN a.account_type = 'asset' AND e.direction = 'credit' "
        'THEN -e.amount_minor '
        "WHEN a.account_type = 'liability' AND e.direction = 'credit' "
        'THEN -e.amount_minor '
        "WHEN a.account_type = 'liability' AND e.direction = 'debit' "
        'THEN e.amount_minor '
        'ELSE 0 END ELSE 0 END), 0) AS net_asset_$i',
      );
      variables.add(Variable<DateTime>(cutoff));
    }
    variables.add(Variable<String>(query.currencyCode));

    return _database
        .customSelect(
          'SELECT ${selects.join(', ')} '
          'FROM entries e '
          'JOIN transactions t ON t.id = e.transaction_id '
          'JOIN accounts a ON a.id = e.account_id '
          "WHERE t.business_state = 'current' "
          'AND t.currency_code = ? '
          "AND a.account_type IN ('asset', 'liability')",
          variables: variables,
          readsFrom: {
            _database.transactions,
            _database.entries,
            _database.accounts,
          },
        )
        .watchSingle()
        .map(
          (row) => [
            for (var i = 0; i < months.length; i++)
              NetAssetTrendPoint(
                month: months[i],
                netAssets: Money(
                  minorUnits: row.read<int>('net_asset_$i'),
                  currency: query.currencyCode,
                ),
              ),
          ],
        );
  }

  String _balanceExpression(
    String alias,
    String accountType,
    String cutoffSql,
  ) {
    final positiveDirection = accountType == 'asset' ? 'debit' : 'credit';
    final negativeDirection = accountType == 'asset' ? 'credit' : 'debit';
    return "COALESCE(SUM(CASE WHEN a.account_type = '$accountType' "
        'AND t.occurred_at $cutoffSql THEN '
        "CASE WHEN e.direction = '$positiveDirection' THEN e.amount_minor "
        "WHEN e.direction = '$negativeDirection' THEN -e.amount_minor "
        'ELSE 0 END ELSE 0 END), 0) AS $alias';
  }

  BalanceSheetSnapshot _snapshot(
    QueryRow row, {
    required String assetsColumn,
    required String liabilitiesColumn,
    required String currencyCode,
  }) {
    return BalanceSheetSnapshot(
      assets: Money(
        minorUnits: row.read<int>(assetsColumn),
        currency: currencyCode,
      ),
      liabilities: Money(
        minorUnits: row.read<int>(liabilitiesColumn),
        currency: currencyCode,
      ),
    );
  }

  List<MonthKey> _trendMonths(MonthKey endMonth, int count) {
    if (count <= 0) {
      return const [];
    }
    return [
      for (var i = count - 1; i >= 0; i--)
        MonthKey.fromDate(DateTime(endMonth.year, endMonth.month - i)),
    ];
  }

  MonthKey _previousMonth(MonthKey month) {
    return MonthKey.fromDate(DateTime(month.year, month.month - 1));
  }

  DateTime _samePeriodUntil(MonthKey month, int day) {
    final nextMonthStart = month.nextMonthStart;
    final lastDay = nextMonthStart.subtract(const Duration(days: 1)).day;
    final inclusiveDay = day > lastDay ? lastDay : day;
    return DateTime(month.year, month.month, inclusiveDay + 1);
  }
}

class _DailyTotals {
  int incomeMinor = 0;
  int expenseMinor = 0;
}
