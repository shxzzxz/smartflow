abstract interface class AssetViewPreferencesStore {
  Future<String?> readSelectedViewId();
  Future<void> saveSelectedViewId(String id);
}
