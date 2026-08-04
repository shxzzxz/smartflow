import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/service/account/category_factory.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/port/transaction_repository.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_violation_reason.dart';

import 'category_command.dart';

abstract interface class CategoryAppService {
  Future<Account> createCategory(CreateCategoryCommand command);

  Future<void> editCategory(EditCategoryCommand command);

  Future<CategoryDeletionPreview> previewCategoryDeletion(String categoryId);

  Future<void> deleteCategory(DeleteCategoryCommand command);
}

class CategoryAppServiceImpl implements CategoryAppService {
  const CategoryAppServiceImpl({
    required AccountRepository repository,
    required TransactionRepository transactionRepository,
    required TransactionRunner transactionRunner,
    required IdGenerator idGenerator,
    CategoryFactory categoryFactory = const CategoryFactory(),
  }) : _repository = repository,
       _transactionRepository = transactionRepository,
       _runner = transactionRunner,
       _idGenerator = idGenerator,
       _categoryFactory = categoryFactory;

  final AccountRepository _repository;
  final TransactionRepository _transactionRepository;
  final TransactionRunner _runner;
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

  @override
  Future<CategoryDeletionPreview> previewCategoryDeletion(
    String categoryId,
  ) async {
    final category = await _loadDeletableCategory(categoryId);
    final children = await _repository.findChildrenOf(category.id);
    return CategoryDeletionPreview(
      category: category,
      childCount: children.length,
      transactionRefCount: await _countTransactionRefs(category.id),
    );
  }

  @override
  Future<void> deleteCategory(DeleteCategoryCommand command) async {
    final category = await _loadDeletableCategory(command.id);
    await _runner.run<void>(() async {
      final children = await _repository.findChildrenOf(category.id);
      if (children.isNotEmpty) {
        LedgerViolationReason.categoryHasChildren.throwException();
      }
      if (await _countTransactionRefs(category.id) > 0) {
        LedgerViolationReason.categoryReferencedByTransactions.throwException();
      }
      await _repository.delete(category.id);
    });
  }

  Future<Account> _loadDeletableCategory(String categoryId) async {
    final category = await _repository.findById(categoryId);
    if (category == null || !category.type.isCategory) {
      throw BusinessException(LedgerErrorCode.categoryNotFound);
    }
    if (!category.isManageableCategory) {
      LedgerViolationReason.categorySystemManaged.throwException();
    }
    if (category.isArchived) {
      LedgerViolationReason.categoryArchived.throwException();
    }
    return category;
  }

  Future<int> _countTransactionRefs(String categoryId) async {
    final entryCounts = await _transactionRepository.countEntriesByAccount({
      categoryId,
    });
    final reimbursementCounts = await _transactionRepository
        .countReimbursementExpenseRefs({categoryId});
    return (entryCounts[categoryId] ?? 0) +
        (reimbursementCounts[categoryId] ?? 0);
  }
}
