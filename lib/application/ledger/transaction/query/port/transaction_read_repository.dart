import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

import '../transaction_queries.dart';

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

  Stream<void> watchChanges();
}
