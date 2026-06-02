import 'package:smartflow/core/time/month_key.dart';

class CashflowComparisonQuery {
  const CashflowComparisonQuery({required this.month, this.asOfDate});

  final MonthKey month;
  final DateTime? asOfDate;
}

class BalanceSheetComparisonQuery {
  const BalanceSheetComparisonQuery({required this.month, this.asOfExclusive});

  final MonthKey month;

  /// 不包含上界。当前月页面可传入 DateTime.now()，历史月默认用下月月初。
  final DateTime? asOfExclusive;
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
