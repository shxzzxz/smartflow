import 'package:smartflow/core/error/failure.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/result/result.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/service/account/category_factory.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';

import 'category_command.dart';

abstract interface class CategoryAppService {
  Future<Result<Account>> createCategory(CreateCategoryCommand command);
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
  Future<Result<Account>> createCategory(CreateCategoryCommand command) async {
    Account? parent;
    final parentId = command.parentId;
    if (parentId != null) {
      parent = await _repository.findById(parentId);
      if (parent == null) {
        return const Result.failure(
          Failure(
            code: 'category_parent_not_found',
            message: 'Parent category does not exist.',
          ),
        );
      }
    }
    final categoryResult = _categoryFactory.createCategory(
      id: _idGenerator.newId(),
      name: command.name,
      type: command.type,
      parent: parent,
      iconKey: command.iconKey,
      note: command.note,
      sortOrder: command.sortOrder,
    );
    final Account category;
    switch (categoryResult) {
      case Success(:final value):
        category = value;
      case FailureResult(:final failure):
        return Result.failure(failure);
    }

    try {
      await _repository.create(category);
      return Result.success(category);
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
}
