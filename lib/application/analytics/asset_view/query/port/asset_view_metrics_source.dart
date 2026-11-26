import '../asset_view_read_models.dart';

abstract interface class AssetViewMetricsSource {
  Stream<AssetViewStatistics> watchStatistics({
    required DateTime asOf,
    required Set<String>? accountIds,
  });
}
