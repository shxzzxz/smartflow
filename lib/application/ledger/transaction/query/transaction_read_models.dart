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

/// 常规列表场景的 read model（`businessState == current` 的视图）。
///
/// 字段说明:
/// - 交易基础字段(来自 transaction 表)
/// - `entries` / `details`:会计事实,UI 装饰(name/icon)由 UI 层通过 accountStore 渲染
/// - 子树聚合:service 派生,仅 root 时填(refundedTotal / reimbursement* )
class TransactionListReadModel {
  const TransactionListReadModel({
    required this.id,
    required this.rootTransactionId,
    required this.businessPurpose,
    required this.businessState,
    required this.occurredAt,
    required this.primaryAmount,
    required this.isExcludedFromStats,
    required this.isExcludedFromBudget,
    required this.entries,
    required this.details,
    this.parentTransactionId,
    this.reimbursementExpenseAccountId,
    this.counterpartyName,
    this.note,
    this.refundedTotal,
    this.refundChildCount = 0,
    this.reimbursementReceivedTotal,
    this.reimbursementChildCount = 0,
    this.reimbursementGapIncome,
    this.reimbursementGapExpense,
  });

  // transaction 字段
  final String id;
  final String rootTransactionId;
  final String? parentTransactionId;
  final BusinessPurpose businessPurpose;
  final BusinessState businessState;
  final DateTime occurredAt;
  final Money primaryAmount;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
  final String? reimbursementExpenseAccountId;

  // 会计事实
  final List<Entry> entries;
  final List<TransactionDetailRecord> details;

  // 子树聚合(service 派生,前端不可派生,仅 root 时填)
  final Money? refundedTotal;
  final int refundChildCount;
  final Money? reimbursementReceivedTotal;
  final int reimbursementChildCount;
  final Money? reimbursementGapIncome;
  final Money? reimbursementGapExpense;
}

/// 更正链场景的 read model
/// (`state != current OR mutation_kind != original` 的历史快照)。
///
/// 与 [TransactionListReadModel] 的区别:含 mutation 元数据;**无子树聚合**(历史快照
/// 不再算业务派生,仅是操作记录)。
class TransactionHistorySnapshot {
  const TransactionHistorySnapshot({
    required this.id,
    required this.rootTransactionId,
    required this.businessPurpose,
    required this.businessState,
    required this.occurredAt,
    required this.primaryAmount,
    required this.mutationKind,
    required this.createdAt,
    required this.entries,
    required this.details,
    this.parentTransactionId,
    this.counterpartyName,
    this.note,
    this.mutationReason,
    this.mutationPreviousTransactionId,
  });

  final String id;
  final String rootTransactionId;
  final String? parentTransactionId;
  final BusinessPurpose businessPurpose;
  final BusinessState businessState;
  final DateTime occurredAt;
  final Money primaryAmount;
  final String? counterpartyName;
  final String? note;

  // 更正链元数据
  final MutationKind mutationKind;
  final MutationReason? mutationReason;
  final String? mutationPreviousTransactionId;

  /// 操作时间(用于历史链按操作顺序排序)。
  final DateTime createdAt;

  // 会计事实
  final List<Entry> entries;
  final List<TransactionDetailRecord> details;
}

/// 详情场景的 read model。
///
/// service 编排:transaction + entries + details + children + history + 业务派生。
class TransactionDetail {
  const TransactionDetail({
    required this.transaction,
    required this.createdAt,
    required this.details,
    required this.entries,
    this.children = const [],
    this.history = const [],
    this.refundedTotal,
    this.reimbursementSummary,
  });

  final Transaction transaction;
  final DateTime createdAt;
  final List<TransactionDetailRecord> details;
  final List<Entry> entries;
  final List<TransactionListReadModel> children;
  final List<TransactionHistorySnapshot> history;
  final Money? refundedTotal;
  final ReimbursementSummary? reimbursementSummary;
}

/// 报销场景的派生视图(advance/received/outstanding/isClosed)。
/// 仅作为 [TransactionDetail.reimbursementSummary] 的字段出现,列表场景不用。
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
