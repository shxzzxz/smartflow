import '../../../core/money/money.dart';
import '../valobj/ledger_enum.dart';

/// transaction / transaction_details 表的明细行(领域实体)。
///
/// 与 `read_model/transaction_read_models.dart` 中 `TransactionDetailLine` 的区别:
/// 实体含 db 标识符(id / transactionId),read model line 仅含会计字段(lineNo/type/amount)。
class TransactionDetailRecord {
  const TransactionDetailRecord({
    required this.id,
    required this.transactionId,
    required this.lineNo,
    required this.type,
    required this.amount,
  });

  final String id;
  final String transactionId;
  final int lineNo;
  final TransactionDetailType type;
  final Money amount;
}
