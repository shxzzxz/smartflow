import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/transaction_group.dart'
    show RefundSummary, ReimbursementSummary;
import 'package:smartflow/domain/ledger/entity/transaction_line.dart';
import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/transaction_ownership.dart';

export 'package:smartflow/domain/ledger/entity/transaction_group.dart'
    show RefundSummary, RefundCategorySummary, ReimbursementSummary;

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

/// 交易读模型。
///
/// [lines] 是按 `lineNo` 排序的业务事实；[impactsByAccountId] 是分录求和后的
/// 账户影响，不作为角色来源。顶层交易在列表与详情中都填充 [children]；子交易
/// 的 [children] 恒为空，因此所有交易组聚合在子交易上都返回零值。
class TransactionReadModel {
  TransactionReadModel({
    required this.id,
    this.parentTransactionId,
    required this.businessPurpose,
    required this.occurredAt,
    DateTime? postedAt,
    required this.primaryAmount,
    this.counterpartyName,
    this.note,
    this.sourceKind = SourceKind.manual,
    this.ownership,
    required this.isExcludedFromStats,
    required this.isExcludedFromBudget,
    this.createdAt,
    List<TransactionLine> lines = const [],
    Map<String, TransactionAccountImpact> impactsByAccountId = const {},
    List<TransactionReadModel> children = const [],
    RefundSummary? refundSummary,
    ReimbursementSummary? reimbursementSummary,
  }) : postedAt = postedAt ?? occurredAt,
       lines = List.unmodifiable(lines),
       impactsByAccountId = Map.unmodifiable(impactsByAccountId),
       children = List.unmodifiable(children),
       refundSummary = refundSummary,
       reimbursementSummary = reimbursementSummary;

  factory TransactionReadModel.fromTransaction({
    required Transaction transaction,
    DateTime? createdAt,
    List<TransactionLine>? lines,
    Map<String, TransactionAccountImpact> impactsByAccountId = const {},
    List<TransactionReadModel> children = const [],
    RefundSummary? refundSummary,
    ReimbursementSummary? reimbursementSummary,
  }) {
    return TransactionReadModel(
      id: transaction.id,
      parentTransactionId: transaction.parentTransactionId,
      businessPurpose: transaction.businessPurpose,
      occurredAt: transaction.occurredAt,
      postedAt: transaction.postedAt,
      primaryAmount: transaction.primaryAmount,
      counterpartyName: transaction.counterpartyName,
      note: transaction.note,
      sourceKind: transaction.sourceKind,
      ownership: transaction.ownership,
      isExcludedFromStats: transaction.isExcludedFromStats,
      isExcludedFromBudget: transaction.isExcludedFromBudget,
      createdAt: createdAt,
      lines: lines ?? transaction.lines,
      impactsByAccountId: impactsByAccountId,
      children: children,
      refundSummary: refundSummary,
      reimbursementSummary: reimbursementSummary,
    );
  }

  final String id;
  final String? parentTransactionId;
  final BusinessPurpose businessPurpose;
  final DateTime occurredAt;
  final DateTime postedAt;
  final Money primaryAmount;
  final String? counterpartyName;
  final String? note;
  final SourceKind sourceKind;
  final TransactionOwnership? ownership;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
  final DateTime? createdAt;
  final List<TransactionLine> lines;
  final Map<String, TransactionAccountImpact> impactsByAccountId;
  final List<TransactionReadModel> children;
  final RefundSummary? refundSummary;
  final ReimbursementSummary? reimbursementSummary;

  TransactionReadModel copyWith({
    List<TransactionLine>? lines,
    Map<String, TransactionAccountImpact>? impactsByAccountId,
    List<TransactionReadModel>? children,
    RefundSummary? refundSummary,
    ReimbursementSummary? reimbursementSummary,
  }) {
    return TransactionReadModel(
      id: id,
      parentTransactionId: parentTransactionId,
      businessPurpose: businessPurpose,
      occurredAt: occurredAt,
      postedAt: postedAt,
      primaryAmount: primaryAmount,
      counterpartyName: counterpartyName,
      note: note,
      sourceKind: sourceKind,
      ownership: ownership,
      isExcludedFromStats: isExcludedFromStats,
      isExcludedFromBudget: isExcludedFromBudget,
      createdAt: createdAt,
      lines: lines ?? this.lines,
      impactsByAccountId: impactsByAccountId ?? this.impactsByAccountId,
      children: children ?? this.children,
      refundSummary: refundSummary ?? this.refundSummary,
      reimbursementSummary: reimbursementSummary ?? this.reimbursementSummary,
    );
  }

  Iterable<TransactionLine> linesOf(TransactionRole role) =>
      lines.where((line) => line.role == role);

  Iterable<TransactionLine> get settlementLines => lines.where(
    (line) =>
        line.role == TransactionRole.settlementIn ||
        line.role == TransactionRole.settlementOut,
  );

  Iterable<TransactionLine> get categoryLines => lines.where(
    (line) =>
        line.role == TransactionRole.category ||
        line.role == TransactionRole.reimbursementExpenseCategory,
  );

  Money amountOf(TransactionRole role) =>
      linesOf(role).fold(Money.zero(), (total, line) => total + line.amount);

  String? accountOf(TransactionRole role) =>
      linesOf(role).firstOrNull?.accountId;
}
