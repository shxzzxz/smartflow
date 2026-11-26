import '../../../application/analytics/asset_view/query/asset_view_read_models.dart';
import '../../../application/analytics/asset_view/query/port/asset_view_metrics_source.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/time/month_key.dart';

class LedgerAssetViewMetricsSource implements AssetViewMetricsSource {
  const LedgerAssetViewMetricsSource(this._metrics);
  final FinancialMetricsService _metrics;
  @override
  Stream<AssetViewStatistics> watchStatistics({
    required DateTime asOf,
    required Set<String>? accountIds,
  }) => _metrics
      .watchBalanceSheetComparison(
        BalanceSheetComparisonQuery(
          month: MonthKey.fromDate(asOf),
          asOfExclusive: DateTime(asOf.year, asOf.month, asOf.day + 1),
          accountIds: accountIds,
        ),
      )
      .map(
        (comparison) => AssetViewStatistics(
          assets: comparison.current.assets,
          liabilities: comparison.current.liabilities,
          netAssetChange: comparison.netAssetChange.delta,
          netAssetChangeRatio: comparison.netAssetChange.ratio,
          isNewNetAssetValue: comparison.netAssetChange.isNewValue,
        ),
      );
}
