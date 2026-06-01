import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/time/month_key.dart';

import '../../transaction/query/transaction_read_models.dart';

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
