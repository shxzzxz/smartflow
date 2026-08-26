import '../../../core/money/money.dart';
import '../valobj/ledger_enum.dart';

/// transaction_lines 表的一行:交易在业务语言中的一条分项。
///
/// 分项是过账输入的完整快照,分录由过账规则从分项生成,二者不同构。
/// [accountId] 的可空性由 [role] 固定:用户账户角色必填,规则账户角色恒空
/// 并在过账时按 `system_key` 解析。
class TransactionLine {
  const TransactionLine({
    required this.id,
    required this.transactionId,
    required this.lineNo,
    required this.role,
    required this.amount,
    this.accountId,
  });

  final String id;
  final String transactionId;
  final int lineNo;
  final TransactionRole role;
  final String? accountId;

  /// 期初余额与余额调整角色带符号,其余角色恒为正。
  final Money amount;
}
