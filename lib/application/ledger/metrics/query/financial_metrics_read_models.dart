import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/time/month_key.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

import '../../transaction/query/transaction_read_models.dart';

class AccountMetric {
  const AccountMetric({
    required this.accountId,
    required this.accountType,
    required this.amountMinor,
  });

  final String accountId;
  final AccountType accountType;
  final int amountMinor;

  Money get amount => Money(minorUnits: amountMinor);

  @override
  bool operator ==(Object other) {
    return other is AccountMetric &&
        other.accountId == accountId &&
        other.accountType == accountType &&
        other.amountMinor == amountMinor;
  }

  @override
  int get hashCode => Object.hash(accountId, accountType, amountMinor);
}

/// 一级分类统计：total 为自身直接金额与全部二级统计项之和。
///
/// 一级分类自身的直接金额以"未细分"二级统计项呈现（使用一级分类的真实 ID），
/// 因此 [items] 金额之和恒等于 [totalMinor]；统计只包含非零节点。
class CategoryMetricGroup {
  CategoryMetricGroup({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.accountType,
    required this.totalMinor,
    required List<CategoryMetricItem> items,
  }) : items = List.unmodifiable(items);

  final String id;
  final String name;
  final String? iconKey;
  final AccountType accountType;
  final int totalMinor;
  final List<CategoryMetricItem> items;

  Money get total => Money(minorUnits: totalMinor);
}

/// 二级分类统计项：只承载该分类自身的直接金额。
class CategoryMetricItem {
  const CategoryMetricItem({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.isUnsubdivided,
    required this.amountMinor,
  });

  final String id;
  final String name;
  final String? iconKey;

  /// 一级分类自身直接金额的"未细分"项；[id] 为一级分类的真实分类 ID。
  final bool isUnsubdivided;

  final int amountMinor;

  Money get amount => Money(minorUnits: amountMinor);
}

class CashflowReport {
  const CashflowReport({
    required this.comparison,
    required this.dailySummaries,
    required this.categories,
  });

  final CashflowComparison comparison;
  final List<DailyCashflowSummary> dailySummaries;
  final List<CategoryMetricGroup> categories;
}

class BalanceReport {
  const BalanceReport({
    required this.comparison,
    required this.trend,
    required this.accounts,
  });

  final BalanceSheetComparison comparison;
  final List<NetAssetTrendPoint> trend;
  final List<AccountMetric> accounts;
}

class StatisticsRangeReport {
  const StatisticsRangeReport({
    required this.from,
    required this.until,
    required this.cashflow,
    required this.dailySummaries,
    required this.categories,
    required this.balanceTrend,
  });

  final DateTime from;
  final DateTime until;
  final CashflowSummary cashflow;
  final List<DailyCashflowSummary> dailySummaries;
  final List<CategoryMetricGroup> categories;
  final List<BalanceTrendPoint> balanceTrend;
}

class BalanceTrendPoint {
  const BalanceTrendPoint({
    required this.date,
    required this.assets,
    required this.liabilities,
  });

  final DateTime date;
  final Money assets;
  final Money liabilities;

  Money get netAssets => assets - liabilities;
}

class DailyCashflowSummary {
  const DailyCashflowSummary({
    required this.date,
    required this.income,
    required this.expense,
  });

  final DateTime date;
  final Money income;
  final Money expense;

  Money get net => income - expense;
}

class CashflowComparison {
  const CashflowComparison({
    required this.current,
    required this.previousSamePeriod,
    required this.previousFullPeriod,
  });

  final CashflowSummary current;
  final CashflowSummary previousSamePeriod;
  final CashflowSummary previousFullPeriod;

  PeriodChange get incomeChange {
    return PeriodChange(
      current: current.income,
      previous: previousSamePeriod.income,
      previousFullPeriod: previousFullPeriod.income,
    );
  }

  PeriodChange get expenseChange {
    return PeriodChange(
      current: current.expense,
      previous: previousSamePeriod.expense,
      previousFullPeriod: previousFullPeriod.expense,
    );
  }
}

class BalanceSheetSnapshot {
  const BalanceSheetSnapshot({required this.assets, required this.liabilities});

  final Money assets;
  final Money liabilities;

  Money get netAssets => assets - liabilities;
}

class BalanceSheetComparison {
  const BalanceSheetComparison({required this.current, required this.previous});

  final BalanceSheetSnapshot current;
  final BalanceSheetSnapshot previous;

  PeriodChange get netAssetChange {
    return PeriodChange(
      current: current.netAssets,
      previous: previous.netAssets,
    );
  }
}

class NetAssetTrendPoint {
  const NetAssetTrendPoint({required this.month, required this.netAssets});

  final MonthKey month;
  final Money netAssets;
}

class PeriodChange {
  const PeriodChange({
    required this.current,
    required this.previous,
    this.previousFullPeriod,
  });

  final Money current;
  final Money previous;
  final Money? previousFullPeriod;

  Money get delta => current - previous;

  /// 上期为 0 时不提供百分比，避免展示无意义的无穷增长。
  double? get ratio {
    final baseline = previous.minorUnits.abs();
    if (baseline == 0) {
      return null;
    }
    return delta.minorUnits / baseline;
  }

  bool get isFlat => delta.minorUnits == 0;
  bool get isNewValue => previous.minorUnits == 0 && current.minorUnits != 0;

  double? get fullPeriodRatio {
    final fullPeriod = previousFullPeriod;
    if (fullPeriod == null || fullPeriod.minorUnits == 0) {
      return null;
    }
    return current.minorUnits / fullPeriod.minorUnits.abs();
  }
}
