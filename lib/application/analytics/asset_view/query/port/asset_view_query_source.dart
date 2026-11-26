import '../../../../../domain/analytics/entity/asset_view.dart';

abstract interface class AssetViewQuerySource {
  Future<AssetView?> findView(String id);
  Future<List<AssetView>> findViews();
  Stream<List<AssetView>> watchViews();
}
