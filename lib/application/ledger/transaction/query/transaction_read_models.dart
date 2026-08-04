import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/entry.dart';
import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/entity/transaction_detail_record.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

class CashflowSummary {
  const CashflowSummary({required this.income, required this.expense});

  final Money income;
  final Money expense;

  Money get net => income - expense;
}

/// 数据清理条件命中的交易组统计。
///
/// 带业务归属的交易组不允许在账务侧直接删除，只计入 [ownedGroupCount]。
class TransactionCleanupPreview {
  const TransactionCleanupPreview({
    required this.matchedGroupCount,
    required this.ownedGroupCount,
  });

  static const TransactionCleanupPreview empty = TransactionCleanupPreview(
    matchedGroupCount: 0,
    ownedGroupCount: 0,
  );

  final int matchedGroupCount;
  final int ownedGroupCount;

  int get deletableGroupCount => matchedGroupCount - ownedGroupCount;
}

class TransactionAccountImpact {
  const TransactionAccountImpact({
    required this.debitAmount,
    required this.creditAmount,
    required this.netChange,
  });

  final Money debitAmount;
  final Money creditAmount;
  final Money netChange;
}

enum TransactionAdjustmentKind {
  refund,
  reimbursementReceived,
  repaymentInterest,
  repaymentFee,
  repaymentDiscount,
  reimbursementGapIncome,
  reimbursementGapExpense,
}

/// 交易组的调整摘要：退款、报销到账、利/费/优与报销差额。
class TransactionAdjustment {
  const TransactionAdjustment({required this.kind, required this.amount});

  final TransactionAdjustmentKind kind;

  /// 恒为正；文案、正负色由 [kind] 决定。
  final Money amount;
}

class TransactionListReadModel {
  const TransactionListReadModel({
    required this.id,
    required this.businessPurpose,
    required this.occurredAt,
    required this.primaryAmount,
    required this.isExcludedFromStats,
    required this.isExcludedFromBudget,
    required this.primaryCategoryId,
    required this.impactsByAccountId,
    required this.adjustments,
  });

  final String id;
  final BusinessPurpose businessPurpose;
  final DateTime occurredAt;
  final Money primaryAmount;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;

  /// 日常收支和报销垫付的角色分类 ID，不等同于全部分类影响。
  final String? primaryCategoryId;

  /// 当前交易自身的全部账户影响，不包含子交易影响。
  final Map<String, TransactionAccountImpact> impactsByAccountId;

  /// 顶层交易可包含交易组调整摘要；子交易恒为空列表。
  final List<TransactionAdjustment> adjustments;
}

class TransactionDetail {
  const TransactionDetail({
    required this.transaction,
    required this.createdAt,
    required this.details,
    required this.entries,
    this.children = const [],
    this.refundedTotal,
    this.reimbursementSummary,
  });

  final Transaction transaction;
  final DateTime createdAt;
  final List<TransactionDetailRecord> details;
  final List<Entry> entries;
  final List<TransactionListReadModel> children;
  final Money? refundedTotal;
  final ReimbursementSummary? reimbursementSummary;
}

class ReimbursementSummary {
  const ReimbursementSummary({
    required this.advanceAmount,
    required this.receivedAmount,
    required this.outstanding,
    required this.isClosed,
  });

  final Money advanceAmount;
  final Money receivedAmount;
  final Money outstanding;
  final bool isClosed;
}
