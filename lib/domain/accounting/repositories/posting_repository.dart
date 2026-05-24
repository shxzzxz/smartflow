import '../../../core/patch/patch.dart';
import '../entities/account.dart';
import '../entities/transaction_ownership.dart';
import '../enums/accounting_enums.dart';
import '../ledger/post_receipt.dart';

/// 账务核心的写入端:提供 receipt 落库 + 余额维护 + transaction 状态变更。
///
/// 接口语义只关心"原子地完成一组写入",不感知"凭证从何而来";具体的凭证编排
/// (create/replace/cancel)在 [Poster] 层完成。
abstract interface class PostingRepository {
  Future<List<Account>> findAccountsByIds(Set<int> ids);

  /// 单笔正向落库。
  ///
  /// - 插入 transactions / transaction_details / entries
  /// - 按 [balanceDeltasMinor] 累加 accounts.balance_minor
  /// - 若 receipt 未提供 [PostReceipt.rootTransactionId],落库后回填为自身 id
  ///
  /// [mutationKind] / [businessState] / [mutationReason] /
  /// [mutationPreviousTransactionId] 由调用方按写入语义提供:
  ///
  /// - 普通新建:`original` / `current` / null / null
  /// - 红字冲销:`reversal` / `compensation` / 调用方指定 / 调用方指定
  Future<PostReceiptResult> insertReceipt({
    required PostReceipt receipt,
    required Map<int, int> balanceDeltasMinor,
    MutationKind mutationKind = MutationKind.original,
    BusinessState businessState = BusinessState.current,
    MutationReason? mutationReason,
    int? mutationPreviousTransactionId,
  });

  /// 在单个 db 事务内完成"original → replaced + reversal + correction"全套写入,
  /// 返回最终 correction 交易的 id 与 root。
  Future<PostReceiptResult> replaceTransaction({
    required int originalTransactionId,
    required PostReceipt reversalReceipt,
    required PostReceipt correctionReceipt,
    required Map<int, int> reversalBalanceDeltasMinor,
    required Map<int, int> correctionBalanceDeltasMinor,
  });

  /// 在单个 db 事务内取消一组交易:每个 [CancelInstruction] 对应
  /// 一笔 original → canceled + 插入对应 reversal。
  Future<void> cancelTransactions({
    required List<CancelInstruction> cancellations,
  });

  Future<void> updateTransactionMetadata({
    required int transactionId,
    Patch<String>? note,
    bool? isExcludedFromStats,
    bool? isExcludedFromBudget,
  });

  Future<void> updateTransactionOwnership({
    required int transactionId,
    required TransactionOwnership ownership,
  });

  Future<void> updateTransactionBasics({
    required int transactionId,
    DateTime? occurredAt,
    List<EntryAccountReassignment> entryAccountReassignments = const [],
  });
}

class CancelInstruction {
  const CancelInstruction({
    required this.originalTransactionId,
    required this.reversalReceipt,
    required this.balanceDeltasMinor,
  });

  final int originalTransactionId;
  final PostReceipt reversalReceipt;
  final Map<int, int> balanceDeltasMinor;
}
