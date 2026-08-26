import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

import '../transaction_queries.dart';
import '../transaction_read_models.dart';

class TransactionChildAggregate {
  const TransactionChildAggregate({
    required this.sumMinor,
    required this.count,
  });

  final int sumMinor;
  final int count;

  static const TransactionChildAggregate empty = TransactionChildAggregate(
    sumMinor: 0,
    count: 0,
  );
}

/// 数据清理条件命中的一个交易组。
class TransactionCleanupTarget {
  const TransactionCleanupTarget({
    required this.transactionId,
    required this.owned,
  });

  /// 顶层交易 ID。
  final String transactionId;

  /// 组内是否存在带业务归属的交易。
  final bool owned;
}

/// 分类迁移条件命中的一个顶层交易组。
class CategoryTransactionTarget {
  const CategoryTransactionTarget({
    required this.transactionId,
    required this.businessPurpose,
  });

  /// 顶层交易 ID。
  final String transactionId;

  final BusinessPurpose businessPurpose;
}

abstract interface class TransactionReadRepository {
  Future<Transaction?> findById(String id);

  Future<DateTime?> findCreatedAt(String id);

  Future<List<Transaction>> findByIds(Set<String> ids);

  Stream<List<Transaction>> watchPage(TransactionPageQuery query);

  Future<List<Transaction>> findChildren({required String parentId});

  Future<Map<String, TransactionChildAggregate>> aggregateChildren({
    required Set<String> parentIds,
    required Set<BusinessPurpose> purposes,
  });

  Future<Map<String, Map<TransactionRole, int>>> aggregateChildLineAmounts({
    required Set<String> parentIds,
    required Set<TransactionRole> roles,
  });

  Future<Map<String, Map<BusinessPurpose, TransactionChildAggregate>>>
  aggregateChildrenByPurpose({
    required Set<String> parentIds,
    required Set<BusinessPurpose> purposes,
  });

  Stream<TransactionCleanupPreview> watchCleanupPreview(
    TransactionCleanupQuery query,
  );

  Future<List<TransactionCleanupTarget>> findCleanupTargets(
    TransactionCleanupQuery query,
  );

  /// 命中 [categoryId] 的顶层交易组：组内任一分录触达该分类，
  /// 或组内任一交易分项引用该分类。
  Future<List<CategoryTransactionTarget>> findCategoryTransactionTargets(
    String categoryId,
  );

  /// 按交易列表稳定排序返回最近一笔命中分类的交易。
  ///
  /// 分类既可能由分录引用，也可能由报销垫付的支出分类分项引用。
  Future<Transaction?> findLatestByCategory(CategoryTransactionQuery query);

  /// 响应 transactions / entries / transaction_lines / accounts 表变化；
  /// 账户与分类快照变化需要触发列表重新投影。
  Stream<void> watchChanges();
}
