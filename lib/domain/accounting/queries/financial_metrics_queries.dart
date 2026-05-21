import '../../../core/money/money.dart';
import '../../../core/time/month_key.dart';

class CashflowComparisonQuery {
  const CashflowComparisonQuery({
    required this.month,
    this.asOfDate,
    this.currencyCode = Money.defaultCurrency,
  });

  final MonthKey month;
  final DateTime? asOfDate;
  final String currencyCode;
}

class BalanceSheetComparisonQuery {
  const BalanceSheetComparisonQuery({
    required this.month,
    this.asOfExclusive,
    this.currencyCode = Money.defaultCurrency,
  });

  final MonthKey month;

  /// 不包含上界。当前月页面可传入 DateTime.now()，历史月默认用下月月初。
  final DateTime? asOfExclusive;
  final String currencyCode;
}

class DailyCashflowSummaryQuery {
  const DailyCashflowSummaryQuery({
    required this.month,
    this.currencyCode = Money.defaultCurrency,
  });

  final MonthKey month;
  final String currencyCode;
}

class NetAssetTrendQuery {
  const NetAssetTrendQuery({
    required this.endMonth,
    this.months = 6,
    this.currentAsOfExclusive,
    this.currencyCode = Money.defaultCurrency,
  });

  final MonthKey endMonth;
  final int months;

  /// 用于当前月最后一个点的截止时间；为空时所有月份都按月末点计算。
  final DateTime? currentAsOfExclusive;
  final String currencyCode;
}
