import '../../../../domain/analytics/entity/asset_view.dart';
import 'asset_view_read_models.dart';
import 'port/asset_view_query_source.dart';
import 'port/asset_view_metrics_source.dart';

abstract interface class AssetViewQueryService {
  Future<AssetView?> findView(String id);
  Future<List<AssetView>> findViews();
  Stream<List<AssetView>> watchViews();
  Stream<AssetViewStatistics> watchStatistics(AssetView view, DateTime asOf);
}

class AssetViewQueryServiceImpl implements AssetViewQueryService {
  const AssetViewQueryServiceImpl({
    required AssetViewQuerySource views,
    required AssetViewMetricsSource metrics,
  }) : _views = views,
       _metrics = metrics;
  final AssetViewQuerySource _views;
  final AssetViewMetricsSource _metrics;
  @override
  Future<AssetView?> findView(String id) => _views.findView(id);
  @override
  Future<List<AssetView>> findViews() => _views.findViews();
  @override
  Stream<List<AssetView>> watchViews() => _views.watchViews();
  @override
  Stream<AssetViewStatistics> watchStatistics(AssetView view, DateTime asOf) =>
      _metrics.watchStatistics(asOf: asOf, accountIds: view.accountIds.toSet());
}
