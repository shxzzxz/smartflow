import '../queries/financial_metrics_queries.dart';
import '../repositories/financial_metrics_repository.dart';
import '../views/financial_metrics_views.dart';

abstract interface class FinancialMetricsService {
  Stream<CashflowComparison> watchCashflowComparison(
    CashflowComparisonQuery query,
  );

  Stream<List<DailyCashflowSummary>> watchDailyCashflowSummaries(
    DailyCashflowSummaryQuery query,
  );

  Stream<BalanceSheetComparison> watchBalanceSheetComparison(
    BalanceSheetComparisonQuery query,
  );

  Stream<List<NetAssetTrendPoint>> watchNetAssetTrend(NetAssetTrendQuery query);
}

class FinancialMetricsServiceImpl implements FinancialMetricsService {
  const FinancialMetricsServiceImpl(this._repository);

  final FinancialMetricsRepository _repository;

  @override
  Stream<CashflowComparison> watchCashflowComparison(
    CashflowComparisonQuery query,
  ) {
    return _repository.watchCashflowComparison(query);
  }

  @override
  Stream<List<DailyCashflowSummary>> watchDailyCashflowSummaries(
    DailyCashflowSummaryQuery query,
  ) {
    return _repository.watchDailyCashflowSummaries(query);
  }

  @override
  Stream<BalanceSheetComparison> watchBalanceSheetComparison(
    BalanceSheetComparisonQuery query,
  ) {
    return _repository.watchBalanceSheetComparison(query);
  }

  @override
  Stream<List<NetAssetTrendPoint>> watchNetAssetTrend(
    NetAssetTrendQuery query,
  ) {
    return _repository.watchNetAssetTrend(query);
  }
}
