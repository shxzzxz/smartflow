import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

import '../read_model/category_read_models.dart';
import 'account_query_service.dart';

abstract interface class CategoryQueryService {
  Stream<List<CategoryNode>> watchCategoryTree(AccountType type);
}

class CategoryQueryServiceImpl implements CategoryQueryService {
  const CategoryQueryServiceImpl({required AccountQueryService accounts})
    : _accounts = accounts;

  final AccountQueryService _accounts;

  @override
  Stream<List<CategoryNode>> watchCategoryTree(AccountType type) {
    return _accounts.watchCategories(type).map(_buildTree);
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
