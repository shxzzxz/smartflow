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

abstract interface class TransactionReadRepository {
  Future<Transaction?> findById(String id);

  Future<DateTime?> findCreatedAt(String id);

  Future<List<Transaction>> findByIds(Set<String> ids);

  Stream<List<Transaction>> watchPage(TransactionListQuery query);

  Future<List<Transaction>> findChildren({required String parentId});

  Future<Map<String, TransactionChildAggregate>> aggregateChildren({
    required Set<String> parentIds,
    required Set<BusinessPurpose> purposes,
  });

  Future<Map<String, Map<TransactionDetailType, int>>>
  aggregateChildDetailAmounts({
    required Set<String> parentIds,
    required Set<TransactionDetailType> detailTypes,
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

  Stream<void> watchChanges();
}
