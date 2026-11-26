import 'dart:convert';

/// Fixed wire conversion for backup v19 -> v20 and database v69 -> v70.
/// Historical codes and fields deliberately do not depend on current entities.
class AssetViewOrganizationV20 {
  const AssetViewOrganizationV20({required this.accounts, required this.views});
  final List<Map<String, Object?>> accounts;
  final List<Map<String, Object?>> views;
}

AssetViewOrganizationV20 upgradeAssetViewOrganizationV20({
  required Iterable<Map<String, Object?>> accounts,
  required Iterable<Map<String, Object?>> groups,
  required Iterable<Map<String, Object?>> views,
}) {
  const defaultId = 'builtin-asset-view-all';
  const defaultName = '默认';
  final accountRows = accounts.toList()..sort(_compareOrder);
  final financialAccounts = accountRows
      .where(
        (row) =>
            row['accountType'] == 'asset' || row['accountType'] == 'liability',
      )
      .toList();
  final groupRows = groups.toList()..sort(_compareOrder);
  final groupDefinitions = [
    for (final group in groupRows)
      {'id': _string(group, 'id'), 'name': _string(group, 'name')},
  ];
  final groupIds = groupDefinitions.map((group) => group['id']).toSet();
  final viewRows = views.toList();
  if (!viewRows.any((row) => row['id'] == defaultId)) {
    viewRows.insert(0, {
      'id': defaultId,
      'name': defaultName,
      'accountIdsJson': '[]',
      'sortOrder': 0,
      'version': 0,
      'createdAt': 0,
      'updatedAt': 0,
    });
  }
  final names = <String>{defaultName};
  final convertedViews = <Map<String, Object?>>[];
  for (final row in viewRows) {
    final builtin = row['id'] == defaultId;
    final selected = builtin
        ? financialAccounts.map((account) => _string(account, 'id')).toList()
        : _ids(row['accountIdsJson']);
    final selectedIds = selected.toSet();
    final ordered = [
      for (final account in financialAccounts)
        if (selectedIds.contains(account['id'])) _string(account, 'id'),
      for (final id in selected)
        if (!financialAccounts.any((account) => account['id'] == id)) id,
    ];
    final assignments = {
      for (final account in financialAccounts)
        if (selectedIds.contains(account['id']) &&
            groupIds.contains(account['groupId']))
          _string(account, 'id'): _string(account, 'groupId'),
    };
    var name = builtin ? defaultName : _string(row, 'name');
    if (!builtin) {
      final base = name;
      var suffix = 2;
      while (!names.add(name)) {
        final ending = ' ($suffix)';
        name =
            '${base.substring(0, base.length > 120 - ending.length ? 120 - ending.length : base.length)}$ending';
        suffix++;
      }
    }
    convertedViews.add(
      {
        ...row,
        'name': name,
        'accountIdsJson': jsonEncode(ordered),
        'groupsJson': jsonEncode(groupDefinitions),
        'accountGroupIdsJson': jsonEncode(assignments),
        if (builtin) 'sortOrder': 0,
      }..remove('blocksJson'),
    );
  }
  return AssetViewOrganizationV20(
    accounts: [
      for (final row in accounts)
        {
          ...row,
          if (row['accountType'] == 'asset' ||
              row['accountType'] == 'liability')
            'sortOrder': 0,
        }..remove('groupId'),
    ],
    views: convertedViews,
  );
}

int _compareOrder(Map<String, Object?> a, Map<String, Object?> b) {
  final order = (a['sortOrder'] as int? ?? 0).compareTo(
    b['sortOrder'] as int? ?? 0,
  );
  if (order != 0) return order;
  final name = _string(a, 'name').compareTo(_string(b, 'name'));
  return name != 0 ? name : _string(a, 'id').compareTo(_string(b, 'id'));
}

String _string(Map<String, Object?> row, String field) {
  final value = row[field];
  if (value is! String) {
    throw const FormatException('Invalid legacy asset view data.');
  }
  return value;
}

List<String> _ids(Object? value) {
  if (value is! String) {
    throw const FormatException('Invalid legacy account scope.');
  }
  final decoded = jsonDecode(value);
  if (decoded is! List ||
      decoded.any((id) => id is! String) ||
      decoded.toSet().length != decoded.length) {
    throw const FormatException('Invalid legacy account scope.');
  }
  return decoded.cast<String>();
}
