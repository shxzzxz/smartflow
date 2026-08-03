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

/// 交易的主收支分类投影。
///
/// 只有日常支出、日常收入与报销垫付有主收支分类，其余交易用途为 `null`。
/// 分类筛选不依赖该字段，始终按物理分录和查询层的分类树展开执行。
class TransactionCategoryRef {
  const TransactionCategoryRef({
    required this.id,
    required this.name,
    required this.iconKey,
  });

  final String id;
  final String name;
  final String? iconKey;
}

/// 非分类结算分录的列表展示投影。
///
/// 页面可根据 businessPurpose 与 direction 组织付款、收款、负债或应收流向；
/// 账户详情页可用 direction + amount 计算该账户的余额变化。
class TransactionSettlementEntryRef {
  const TransactionSettlementEntryRef({
    required this.accountId,
    required this.accountName,
    required this.accountIconKey,
    required this.direction,
    required this.amount,
  });

  final String accountId;
  final String accountName;
  final String? accountIconKey;
  final EntryDirection direction;
  final Money amount;
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
    required this.category,
    required this.settlementEntries,
    required this.adjustments,
  });

  final String id;
  final BusinessPurpose businessPurpose;
  final DateTime occurredAt;
  final Money primaryAmount;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
  final TransactionCategoryRef? category;
  final List<TransactionSettlementEntryRef> settlementEntries;
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
