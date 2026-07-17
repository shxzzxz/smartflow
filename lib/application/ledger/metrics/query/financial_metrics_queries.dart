import 'package:smartflow/core/time/month_key.dart';

class CashflowComparisonQuery {
  const CashflowComparisonQuery({required this.month, this.asOfDate});

  final MonthKey month;
  final DateTime? asOfDate;
}

class CashflowReportQuery {
  const CashflowReportQuery({required this.month, this.asOfDate});

  final MonthKey month;
  final DateTime? asOfDate;
}

class StatisticsRangeReportQuery {
  StatisticsRangeReportQuery({
    required this.from,
    required this.until,
    this.balancePointIntervalDays = 1,
  }) : assert(from.isBefore(until)),
       assert(balancePointIntervalDays > 0);

  final DateTime from;
  final DateTime until;
  final int balancePointIntervalDays;
}

class BalanceSheetComparisonQuery {
  const BalanceSheetComparisonQuery({required this.month, this.asOfExclusive});

  final MonthKey month;

  /// 不包含上界。当前月页面可传入 DateTime.now()，历史月默认用下月月初。
  final DateTime? asOfExclusive;
}

class BalanceReportQuery {
  const BalanceReportQuery({
    required this.month,
    this.asOfExclusive,
    this.trendMonths = 6,
  });

  final MonthKey month;
  final DateTime? asOfExclusive;
  final int trendMonths;
}

class DailyCashflowSummaryQuery {
  const DailyCashflowSummaryQuery({required this.month});

  final MonthKey month;
}

class NetAssetTrendQuery {
  const NetAssetTrendQuery({
    required this.endMonth,
    this.months = 6,
    this.currentAsOfExclusive,
  });

  final MonthKey endMonth;
  final int months;

  /// 用于当前月最后一个点的截止时间；为空时所有月份都按月末点计算。
  final DateTime? currentAsOfExclusive;
}
