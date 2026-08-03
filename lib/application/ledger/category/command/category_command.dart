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

/// 删除只处理无交易引用且无子分类的单个分类；不满足条件时拒绝。
class DeleteCategoryCommand {
  const DeleteCategoryCommand({required this.id});

  final String id;
}

/// 删除预演：给确认弹窗判断当前分类能否删除，以及不能删除的原因。
class CategoryDeletionPreview {
  const CategoryDeletionPreview({
    required this.category,
    required this.childCount,
    required this.transactionRefCount,
  });

  final Account category;

  /// active 子分类数量；一级分类须先处理或删除其二级分类。
  final int childCount;

  /// 交易引用数量：分类分录引用 + 报销垫付支出分类引用。
  final int transactionRefCount;

  bool get canDelete => childCount == 0 && transactionRefCount == 0;
}

class CategoryTransactionMigrationCommand {
  const CategoryTransactionMigrationCommand({
    required this.sourceCategoryId,
    required this.targetCategoryId,
  });

  final String sourceCategoryId;
  final String targetCategoryId;
}

class CategoryTransactionMigrationResult {
  const CategoryTransactionMigrationResult({required this.migratedGroupCount});

  /// 本次迁移重写的顶层交易组数量。
  final int migratedGroupCount;
}
