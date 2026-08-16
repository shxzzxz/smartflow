/// 标签词表读模型。
///
/// [usageCount] 是当前引用该标签的顶层交易数量，用于删除确认与词表管理展示；
/// 不参与任何统计口径。
class TagView {
  const TagView({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.usageCount,
  });

  final String id;
  final String name;
  final int sortOrder;
  final int usageCount;

  @override
  bool operator ==(Object other) =>
      other is TagView &&
      other.id == id &&
      other.name == name &&
      other.sortOrder == sortOrder &&
      other.usageCount == usageCount;

  @override
  int get hashCode => Object.hash(id, name, sortOrder, usageCount);
}
