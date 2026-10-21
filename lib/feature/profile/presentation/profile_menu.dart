enum ProfileGroupLayout { grid, list }

class ProfileMenuEntry {
  const ProfileMenuEntry({
    required this.title,
    required this.iconKey,
    required this.onTap,
    this.value,
  });

  final String title;
  final String? value;
  final String iconKey;
  final void Function() onTap;
}

class ProfileMenuGroup {
  const ProfileMenuGroup({
    required this.title,
    required this.layout,
    required this.entries,
  });

  final String title;
  final ProfileGroupLayout layout;
  final List<ProfileMenuEntry> entries;
}

/// 在 3-5 列范围内选择更均衡的布局，并优先减少行数。
///
/// 例如 14 个入口在允许 5 列时渲染为 5 列 3 行，而不是 3 列 5 行。
int profileGridColumnCount({required int entryCount, required int maxColumns}) {
  if (entryCount <= 0) return 0;
  final upperBound = maxColumns.clamp(3, 5);
  if (entryCount <= 3) return 3;
  if (entryCount <= upperBound) return entryCount;
  final rowCount = (entryCount / upperBound).ceil();
  return (entryCount / rowCount).ceil().clamp(3, upperBound);
}
