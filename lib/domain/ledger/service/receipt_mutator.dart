import '../valobj/post_receipt.dart';
import '../valobj/transaction_fact.dart';

/// 把已有交易事实派生为新凭证的纯函数领域服务。
///
/// - [deriveReversal]:从 [TransactionFact] 派生红字凭证(金额取负、方向不变、
///   occurredAt 沿用原交易),供 correction / cancel 路径冲销账务。
/// - [inheritFromOriginal]:把"独立合法"的新蓝字凭证包装为 correction —— 从
///   original 继承 root / parent / sourceKind / ownership /
///   reimbursementExpenseAccountId,其它字段沿用 newReceipt。
///
/// 无 IO、无事务边界。caller(application 层 PostingAppService)负责加载
/// [TransactionFact]、控制事务、把派生结果落库。
class ReceiptMutator {
  const ReceiptMutator();

  PostReceipt deriveReversal(TransactionFact original) {
    final t = original.transaction;
    return PostReceipt(
      businessPurpose: t.businessPurpose,
      occurredAt: t.occurredAt,
      primaryAmount: -t.primaryAmount,
      counterpartyName: t.counterpartyName,
      note: t.note,
      rootTransactionId: t.rootTransactionId,
      parentTransactionId: t.parentTransactionId,
      reimbursementExpenseAccountId: t.reimbursementExpenseAccountId,
      isExcludedFromStats: t.isExcludedFromStats,
      isExcludedFromBudget: t.isExcludedFromBudget,
      sourceKind: t.sourceKind,
      ownership: t.ownership,
      details: [
        for (final line in original.details)
          ReceiptDetail(
            lineNo: line.lineNo,
            type: line.type,
            amount: -line.amount,
          ),
      ],
      entries: [
        for (final entry in original.entries)
          ReceiptEntry(
            accountId: entry.accountId,
            direction: entry.direction,
            amount: -entry.amount,
          ),
      ],
    );
  }

  PostReceipt inheritFromOriginal(
    PostReceipt newReceipt,
    TransactionFact original,
  ) {
    final t = original.transaction;
    return newReceipt.copyWith(
      rootTransactionId: t.rootTransactionId,
      parentTransactionId: t.parentTransactionId,
      reimbursementExpenseAccountId:
          newReceipt.reimbursementExpenseAccountId ??
          t.reimbursementExpenseAccountId,
      sourceKind: t.sourceKind,
      ownership: t.ownership,
    );
  }
}
