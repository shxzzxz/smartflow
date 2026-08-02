import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';

part 'asset_section_collapse_view_model.g.dart';

@Riverpod(keepAlive: true)
class AssetSectionCollapseViewModel extends _$AssetSectionCollapseViewModel {
  @override
  Future<Set<String>> build() {
    return ref.watch(assetSectionCollapseStoreProvider).read();
  }

  Future<void> toggle(String sectionKey) {
    return _save((collapsed) {
      return collapsed.contains(sectionKey)
          ? (collapsed..remove(sectionKey))
          : (collapsed..add(sectionKey));
    });
  }

  Future<void> collapseAll(Iterable<String> sectionKeys) {
    return _save((collapsed) => collapsed..addAll(sectionKeys));
  }

  Future<void> expandAll() {
    return _save((collapsed) => collapsed..clear());
  }

  Future<void> _save(
    Set<String> Function(Set<String> collapsed) change,
  ) async {
    final next = change({...state.value ?? const <String>{}});
    state = AsyncData(next);
    await ref.read(assetSectionCollapseStoreProvider).save(next);
  }
}
