abstract interface class AssetSectionCollapseStore {
  Future<Set<String>> read();

  Future<void> save(Set<String> collapsedSectionKeys);
}
