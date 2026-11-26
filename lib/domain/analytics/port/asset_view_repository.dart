import '../entity/asset_view.dart';

abstract interface class AssetViewRepository {
  Future<AssetView?> findView(String id);
  Future<List<AssetView>> findViews();
  Future<void> create(AssetView view);
  Future<void> save(AssetView view);
  Future<void> delete(String id);
}
