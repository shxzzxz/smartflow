import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../commands/category_commands.dart';
import '../entities/account.dart';
import '../enums/accounting_enums.dart';
import '../repositories/account_repository.dart';
import '../views/category_views.dart';

abstract interface class CategoryService {
  Stream<List<CategoryNode>> watchCategoryTree(AccountType type);

  Future<Result<Account>> createCategory(CreateCategoryCommand command);
}

class CategoryServiceImpl implements CategoryService {
  const CategoryServiceImpl(this._repository);

  final CategoryRepository _repository;

  @override
  Stream<List<CategoryNode>> watchCategoryTree(AccountType type) {
    return _repository.watchCategories(type).map(_buildTree);
  }

  @override
  Future<Result<Account>> createCategory(CreateCategoryCommand command) async {
    final failure = await _validateCreate(command);
    if (failure != null) {
      return Result.failure(failure);
    }

    try {
      final spec = CategoryInsertSpec(
        name: command.name.trim(),
        type: command.type,
        currencyCode: command.currencyCode,
        parentId: command.parentId,
        iconKey: _blankToNull(command.iconKey),
        note: _blankToNull(command.note),
        sortOrder: command.sortOrder,
      );
      final account = await _repository.createCategory(spec);
      return Result.success(account);
    } on Object catch (error) {
      return Result.failure(
        Failure(
          code: 'category_create_failed',
          message: 'Failed to create category.',
          cause: error,
        ),
      );
    }
  }

  Future<Failure?> _validateCreate(CreateCategoryCommand command) async {
    if (command.name.trim().isEmpty) {
      return const Failure(
        code: 'category_name_required',
        message: 'Category name is required.',
      );
    }
    if (command.type != AccountType.income &&
        command.type != AccountType.expense) {
      return const Failure(
        code: 'category_type_invalid',
        message: 'Only income and expense categories can be created.',
      );
    }

    final parentId = command.parentId;
    if (parentId == null) {
      return null;
    }

    final parent = await _repository.findCategoryById(parentId);
    if (parent == null) {
      return const Failure(
        code: 'category_parent_not_found',
        message: 'Parent category does not exist.',
      );
    }
    if (parent.archivedAt != null) {
      return const Failure(
        code: 'category_parent_archived',
        message: 'Archived categories cannot be used as parents.',
      );
    }
    if (parent.type != command.type) {
      return const Failure(
        code: 'category_parent_type_mismatch',
        message: 'Parent category type must match child category type.',
      );
    }
    if (parent.parentId != null) {
      return const Failure(
        code: 'category_depth_exceeded',
        message: 'Categories support one child level in this stage.',
      );
    }

    return null;
  }

  List<CategoryNode> _buildTree(List<Account> categories) {
    final childrenByParent = <int, List<Account>>{};
    final roots = <Account>[];

    for (final category in categories) {
      final parentId = category.parentId;
      if (parentId == null) {
        roots.add(category);
      } else {
        childrenByParent.putIfAbsent(parentId, () => []).add(category);
      }
    }

    return [
      for (final root in roots)
        CategoryNode(
          account: root,
          children: childrenByParent[root.id] ?? const [],
        ),
    ];
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}