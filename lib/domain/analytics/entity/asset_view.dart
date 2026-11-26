import '../../../core/error/app_exception.dart';
import '../valobj/analytics_error_code.dart';

class AssetViewGroup {
  AssetViewGroup({required this.id, required String name})
    : name = _name(name, AnalyticsErrorCode.invalidGroup) {
    if (id.trim().isEmpty || id == 'ungrouped') {
      throw BusinessException(AnalyticsErrorCode.invalidGroup);
    }
  }

  final String id;
  final String name;
}

/// A saved account scope with its own groups and account order.
class AssetView {
  AssetView({
    required this.id,
    required String name,
    Iterable<String> accountIds = const [],
    Iterable<AssetViewGroup> groups = const [],
    Map<String, String> accountGroupIds = const {},
    this.sortOrder = 0,
    this.version = 0,
  }) : name = _name(name, AnalyticsErrorCode.invalidView),
       accountIds = List.unmodifiable(accountIds),
       groups = List.unmodifiable(groups),
       accountGroupIds = Map.unmodifiable(accountGroupIds) {
    if (id.trim().isEmpty ||
        version < 0 ||
        sortOrder < 0 ||
        this.accountIds.any((id) => id.trim().isEmpty) ||
        this.accountIds.toSet().length != this.accountIds.length) {
      throw BusinessException(AnalyticsErrorCode.invalidView);
    }
    if (isBuiltin && (this.name != defaultName || sortOrder != 0)) {
      throw BusinessException(AnalyticsErrorCode.builtinView);
    }
    if (!isBuiltin && this.accountIds.isEmpty) {
      throw BusinessException(
        AnalyticsErrorCode.invalidView,
        message: '请至少选择一个账户。',
      );
    }
    final groupIds = this.groups.map((group) => group.id).toSet();
    if (groupIds.length != this.groups.length ||
        !this.accountIds.toSet().containsAll(this.accountGroupIds.keys) ||
        !groupIds.containsAll(this.accountGroupIds.values)) {
      throw BusinessException(AnalyticsErrorCode.invalidGroup);
    }
  }

  // Keep the persisted identity so saved selections continue to resolve.
  static const defaultId = 'builtin-asset-view-all';
  static const defaultName = '默认';

  final String id;
  final String name;
  final List<String> accountIds;
  final List<AssetViewGroup> groups;
  final Map<String, String> accountGroupIds;
  final int sortOrder;
  final int version;

  bool get isBuiltin => id == defaultId;
  bool includesAccount(String id) => accountIds.contains(id);
  String? groupIdFor(String accountId) => accountGroupIds[accountId];
  List<String> accountsInGroup(String? groupId) => [
    for (final id in accountIds)
      if (groupIdFor(id) == groupId) id,
  ];

  AssetView addGroup(AssetViewGroup group) =>
      copyWith(groups: [...groups, group]);

  AssetView renameGroup(String id, String name) {
    _requireGroup(id);
    return copyWith(
      groups: [
        for (final group in groups)
          group.id == id ? AssetViewGroup(id: id, name: name) : group,
      ],
    );
  }

  AssetView deleteGroup(String id) {
    _requireGroup(id);
    return copyWith(
      groups: groups.where((group) => group.id != id),
      accountGroupIds: {
        for (final entry in accountGroupIds.entries)
          if (entry.value != id) entry.key: entry.value,
      },
    );
  }

  AssetView reorderGroups(List<String> ids) {
    _requireSameIds(groups.map((group) => group.id), ids);
    return copyWith(
      groups: [
        for (final id in ids) groups.firstWhere((group) => group.id == id),
      ],
    );
  }

  AssetView moveAccount(String accountId, String? groupId) {
    if (!includesAccount(accountId)) {
      throw BusinessException(AnalyticsErrorCode.invalidReferences);
    }
    if (groupId != null) _requireGroup(groupId);
    if (groupIdFor(accountId) == groupId) return this;
    return copyWith(
      accountIds: [...accountIds.where((id) => id != accountId), accountId],
      accountGroupIds: {
        for (final entry in accountGroupIds.entries)
          if (entry.key != accountId) entry.key: entry.value,
        accountId: ?groupId,
      },
    );
  }

  AssetView reorderAccounts(String? groupId, List<String> ids) {
    if (groupId != null) _requireGroup(groupId);
    _requireSameIds(accountsInGroup(groupId), ids);
    final order = ids.iterator;
    return copyWith(
      accountIds: [
        for (final id in accountIds)
          if (groupIdFor(id) == groupId) (order..moveNext()).current else id,
      ],
    );
  }

  AssetView copyWith({
    String? name,
    Iterable<String>? accountIds,
    Iterable<AssetViewGroup>? groups,
    Map<String, String>? accountGroupIds,
    int? sortOrder,
    int? version,
  }) => AssetView(
    id: id,
    name: name ?? this.name,
    accountIds: accountIds ?? this.accountIds,
    groups: groups ?? this.groups,
    accountGroupIds: accountGroupIds ?? this.accountGroupIds,
    sortOrder: sortOrder ?? this.sortOrder,
    version: version ?? this.version,
  );

  void _requireGroup(String id) {
    if (!groups.any((group) => group.id == id)) {
      throw BusinessException(AnalyticsErrorCode.invalidGroup);
    }
  }

  void _requireSameIds(Iterable<String> actual, List<String> requested) {
    final ids = actual.toSet();
    if (ids.length != requested.length ||
        ids.length != requested.toSet().length ||
        !ids.containsAll(requested)) {
      throw BusinessException(AnalyticsErrorCode.concurrentUpdate);
    }
  }
}

String _name(String value, AnalyticsErrorCode code) {
  final name = value.trim();
  if (name.isEmpty || name.length > 120) {
    throw BusinessException(code, message: '名称需为 1 至 120 个字符。');
  }
  return name;
}
