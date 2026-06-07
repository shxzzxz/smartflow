import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/service/account/category_factory.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

import 'category_command.dart';

abstract interface class CategoryAppService {
  Future<Account> createCategory(CreateCategoryCommand command);

  Future<void> editCategory(EditCategoryCommand command);
}

class CategoryAppServiceImpl implements CategoryAppService {
  const CategoryAppServiceImpl({
    required AccountRepository repository,
    required IdGenerator idGenerator,
    CategoryFactory categoryFactory = const CategoryFactory(),
  }) : _repository = repository,
       _idGenerator = idGenerator,
       _categoryFactory = categoryFactory;

  final AccountRepository _repository;
  final IdGenerator _idGenerator;
  final CategoryFactory _categoryFactory;

  @override
  Future<Account> createCategory(CreateCategoryCommand command) async {
    Account? parent;
    final parentId = command.parentId;
    if (parentId != null) {
      parent = await _repository.findById(parentId);
      if (parent == null) {
        throw BusinessException(
          LedgerErrorCode.categoryInvalidParent,
          message: 'Parent category does not exist.',
        );
      }
    }
    final category = _categoryFactory.createCategory(
      id: _idGenerator.newId(),
      name: command.name,
      type: command.type,
      parent: parent,
      iconKey: command.iconKey,
      note: command.note,
      sortOrder: command.sortOrder,
    );

    await _repository.create(category);
    return category;
  }

  @override
  Future<void> editCategory(EditCategoryCommand command) async {
    final category = await _repository.findById(command.id);
    if (category == null || !category.type.isCategory) {
      throw BusinessException(LedgerErrorCode.categoryNotFound);
    }
    if (category.isArchived) {
      throw BusinessException(LedgerErrorCode.categoryUnavailable);
    }
    final nextParentId = command.parentId.applyTo(category.parentId);
    Account? parent;
    if (nextParentId != null) {
      if (nextParentId == category.id) {
        throw BusinessException(
          LedgerErrorCode.categoryInvalidParent,
          message: 'Category cannot use itself as parent.',
        );
      }
      parent = await _repository.findById(nextParentId);
      if (parent == null) {
        throw BusinessException(
          LedgerErrorCode.categoryInvalidParent,
          message: 'Parent category does not exist.',
        );
      }
      if (category.parentId == null) {
        final children = await _repository.findChildrenOf(category.id);
        if (children.isNotEmpty) {
          throw BusinessException(
            LedgerErrorCode.categoryInvalidParent,
            message: '已有子分类，不能设为子分类。',
          );
        }
      }
    }

    category.changeCategoryProfile(
      CategoryProfilePatch(
        name: command.name,
        iconKey: command.iconKey,
        note: command.note,
      ),
    );
    category.moveCategoryTo(parent);
    await _repository.save(category);
  }
}
