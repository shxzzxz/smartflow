import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

class CreateCategoryCommand {
  const CreateCategoryCommand({
    required this.name,
    required this.type,
    this.parentId,
    this.iconKey,
    this.note,
    this.sortOrder = 0,
  });

  final String name;
  final AccountType type;
  final String? parentId;
  final String? iconKey;
  final String? note;
  final int sortOrder;
}

class EditCategoryCommand {
  const EditCategoryCommand({
    required this.id,
    this.name,
    this.parentId,
    this.iconKey,
    this.note,
  });

  final String id;
  final String? name;
  final Patch<String>? parentId;
  final Patch<String>? iconKey;
  final Patch<String>? note;
}

/// 有引用或有挂载时 [mergeTargetId] 必填，指定交易统计的承接分类。
class DeleteCategoryCommand {
  const DeleteCategoryCommand({required this.id, this.mergeTargetId});

  final String id;
  final String? mergeTargetId;
}

enum CategoryDeletionDisposition {
  /// 无分录引用，物理删除。
  physicalDelete,

  /// 有分录引用，归档并把统计归属并入承接分类。
  archiveMerge,
}

class CategoryDeletionPlanNode {
  const CategoryDeletionPlanNode({required this.category, required this.entryCount});

  final Account category;
  final int entryCount;

  CategoryDeletionDisposition get disposition =>
      entryCount > 0
          ? CategoryDeletionDisposition.archiveMerge
          : CategoryDeletionDisposition.physicalDelete;
}

/// 删除预演：整树处置明细，供确认弹窗展示与承接分类选择。
class CategoryDeletionPreview {
  CategoryDeletionPreview({
    required this.root,
    required List<CategoryDeletionPlanNode> children,
    required List<Account> mounts,
  }) : children = List.unmodifiable(children),
       mounts = List.unmodifiable(mounts);

  final CategoryDeletionPlanNode root;
  final List<CategoryDeletionPlanNode> children;

  /// 挂在被删子树上的归档节点，删除时随承接目标重挂。
  final List<Account> mounts;

  List<CategoryDeletionPlanNode> get nodes => [root, ...children];

  int get totalEntryCount =>
      nodes.fold(0, (sum, node) => sum + node.entryCount);

  bool get requiresMergeTarget =>
      mounts.isNotEmpty ||
      nodes.any(
        (node) => node.disposition == CategoryDeletionDisposition.archiveMerge,
      );

  /// 承接分类不可选自身或被删子树内节点。
  Set<String> get excludedTargetIds => {for (final node in nodes) node.category.id};
}
