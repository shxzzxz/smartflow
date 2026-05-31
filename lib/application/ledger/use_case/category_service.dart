import '../../../core/error/failure.dart';
import '../../../core/id/id_generator.dart';
import '../../../core/result/result.dart';
import '../command/category_command.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/service/category_factory.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import '../query/account_query_repository.dart';
import '../read_model/category_read_models.dart';

abstract interface class CategoryAppService {
  Stream<List<CategoryNode>> watchCategoryTree(AccountType type);

  Future<Result<Account>> createCategory(CreateCategoryCommand command);
}

class CategoryAppServiceImpl implements CategoryAppService {
  const CategoryAppServiceImpl({
    required AccountRepository repository,
    required AccountQueryRepository queries,
    required IdGenerator idGenerator,
    CategoryFactory categoryFactory = const CategoryFactory(),
  }) : _repository = repository,
       _queries = queries,
       _idGenerator = idGenerator,
       _categoryFactory = categoryFactory;

  final AccountRepository _repository;
  final AccountQueryRepository _queries;
  final IdGenerator _idGenerator;
  final CategoryFactory _categoryFactory;

  @override
  Stream<List<CategoryNode>> watchCategoryTree(AccountType type) {
    return _queries.watchCategories(type).map(_buildTree);
  }

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

  List<CategoryNode> _buildTree(List<Account> categories) {
    final childrenByParent = <String, List<Account>>{};
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
}
