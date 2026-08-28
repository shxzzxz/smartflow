import 'package:smartflow/domain/ledger/entity/transaction_line.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

/// transaction_lines 表的纯读能力。
abstract interface class TransactionLineReadRepository {
  /// 按 transactionId 集合取关联分项。返回 `Map<transactionId, lines>`。
  Future<Map<String, List<TransactionLine>>> findByTransactionIds(
    Set<String> transactionIds,
  );

  /// 按主交易 id 集合 + 角色集合,按角色分桶求和。
  /// 用于「主交易自身的分项金额聚合」(如还款的利息 / 手续费 / 优惠)。
  Future<Map<String, Map<TransactionRole, int>>> sumOwnByRole({
    required Set<String> transactionIds,
    required Set<TransactionRole> roles,
  });
}
