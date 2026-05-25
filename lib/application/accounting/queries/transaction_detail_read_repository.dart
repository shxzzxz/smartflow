import 'package:smartflow/domain/accounting/entities/transaction_detail_record.dart';
import 'package:smartflow/domain/accounting/enums/accounting_enums.dart';

/// transaction_details 表的纯读能力。
abstract interface class TransactionDetailReadRepository {
  /// 按 transactionId 集合取关联 details。返回 `Map<transactionId, details>`。
  Future<Map<int, List<TransactionDetailRecord>>> findByTransactionIds(
    Set<int> transactionIds,
  );

  /// 按主交易 id 集合 + detail type 集合,按 type 分桶求和。
  /// 用于「主交易自身的 detail amount 聚合」(如还款 detail 的利息/手续费/折扣)。
  Future<Map<int, Map<TransactionDetailType, int>>> sumOwnByType({
    required Set<int> transactionIds,
    required Set<TransactionDetailType> detailTypes,
  });
}
