import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../valobj/post_receipt.dart';
import '../valobj/ledger_enum.dart';
import '../valobj/transaction_ownership.dart';

class Transaction {
  const Transaction({
    required int id,
    required int rootTransactionId,
    required this.businessPurpose,
    required this.occurredAt,
    required this.primaryAmount,
    required this.mutationKind,
    required this.businessState,
    required this.isExcludedFromStats,
    required this.isExcludedFromBudget,
    required this.sourceKind,
    required this.createdAt,
    this.ownership,
    this.counterpartyName,
    this.note,
    this.parentTransactionId,
    this.reimbursementExpenseAccountId,
    this.mutationPreviousTransactionId,
    this.mutationReason,
  }) : _id = id,
       _rootTransactionId = rootTransactionId,
       details = const [],
       entries = const [];

  const Transaction._({
    required int? id,
    required int? rootTransactionId,
    required this.businessPurpose,
    required this.occurredAt,
    required this.primaryAmount,
    required this.mutationKind,
    required this.businessState,
    required this.isExcludedFromStats,
    required this.isExcludedFromBudget,
    required this.sourceKind,
    required this.createdAt,
    required this.details,
    required this.entries,
    this.ownership,
    this.counterpartyName,
    this.note,
    this.parentTransactionId,
    this.reimbursementExpenseAccountId,
    this.mutationPreviousTransactionId,
    this.mutationReason,
  }) : _id = id,
       _rootTransactionId = rootTransactionId;

  /// 由已校验的 [PostReceipt] 派生的工厂。
  ///
  /// 凭证级合法性由 caller(`PostingAppService`)通过 [PostReceipt.validate]
  /// 在调用本工厂之前完成,本工厂只承担"组装持久化形态"。
  factory Transaction.fromReceipt(
    PostReceipt receipt, {
    MutationKind mutationKind = MutationKind.original,
    BusinessState businessState = BusinessState.current,
    MutationReason? mutationReason,
    int? mutationPreviousTransactionId,
  }) {
    return Transaction._(
      id: null,
      rootTransactionId: receipt.rootTransactionId,
      businessPurpose: receipt.businessPurpose,
      occurredAt: receipt.occurredAt,
      primaryAmount: receipt.primaryAmount,
      counterpartyName: receipt.counterpartyName,
      note: receipt.note,
      parentTransactionId: receipt.parentTransactionId,
      reimbursementExpenseAccountId: receipt.reimbursementExpenseAccountId,
      mutationKind: mutationKind,
      mutationPreviousTransactionId: mutationPreviousTransactionId,
      mutationReason: mutationReason,
      businessState: businessState,
      isExcludedFromStats: receipt.isExcludedFromStats,
      isExcludedFromBudget: receipt.isExcludedFromBudget,
      sourceKind: receipt.sourceKind,
      ownership: receipt.ownership,
      createdAt: DateTime.now(),
      details: List.unmodifiable(receipt.details),
      entries: List.unmodifiable(receipt.entries),
    );
  }

  final int? _id;
  final int? _rootTransactionId;

  int get id {
    final value = _id;
    if (value == null) {
      throw StateError('Transaction has not been persisted yet.');
    }
    return value;
  }

  int get rootTransactionId {
    final value = _rootTransactionId;
    if (value == null) {
      throw StateError('Transaction root has not been persisted yet.');
    }
    return value;
  }

  int? get persistedId => _id;

  int? get persistedRootTransactionId => _rootTransactionId;

  final BusinessPurpose businessPurpose;
  final DateTime occurredAt;
  final Money primaryAmount;
  final String? counterpartyName;
  final String? note;
  final int? parentTransactionId;
  final int? reimbursementExpenseAccountId;
  final MutationKind mutationKind;
  final int? mutationPreviousTransactionId;
  final MutationReason? mutationReason;
  final BusinessState businessState;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
  final SourceKind sourceKind;
  final TransactionOwnership? ownership;
  final DateTime createdAt;
  final List<ReceiptDetail> details;
  final List<ReceiptEntry> entries;

  Set<int> get accountIds => entries.map((entry) => entry.accountId).toSet();

  /// 删除路径:仅 current 可删,replaced / canceled / compensation 拒绝。
  Failure? assertCanBeDeleted() {
    if (businessState != BusinessState.current) {
      return const Failure(
        code: 'transaction_not_current',
        message: 'Only current transaction can be deleted.',
      );
    }
    return null;
  }

  /// 更正路径:current + purpose 匹配 + 无 active children。
  /// [hasActiveChildren] 由 application 层基于 TransactionDetail.children 派生。
  Failure? assertCanBeCorrectedAs(
    BusinessPurpose expected, {
    required bool hasActiveChildren,
  }) {
    if (businessState != BusinessState.current) {
      return const Failure(
        code: 'transaction_not_current',
        message: 'Only current transaction can be corrected.',
      );
    }
    if (businessPurpose != expected) {
      return const Failure(
        code: 'transaction_correction_purpose_mismatch',
        message: 'Correction command purpose must match the transaction.',
      );
    }
    if (hasActiveChildren) {
      return const Failure(
        code: 'transaction_has_children',
        message:
            'Transactions with child records cannot be corrected; '
            'use updateTransactionMetadata to change note / exclusion flags.',
      );
    }
    return null;
  }

  /// 基础信息(occurredAt / settlement / reimbursement account)更新路径。
  Failure? assertCanBeBasicsUpdated() {
    if (businessState != BusinessState.current) {
      return const Failure(
        code: 'transaction_not_current',
        message: 'Only current transaction can be updated.',
      );
    }
    return null;
  }

  Transaction withPersistedIdentity({
    required int id,
    required int rootTransactionId,
  }) {
    return _copyWith(id: id, rootTransactionId: rootTransactionId);
  }

  Transaction markReplaced() {
    return _copyWith(businessState: BusinessState.replaced);
  }

  Transaction markCanceled() {
    return _copyWith(businessState: BusinessState.canceled);
  }

  /// 更新元数据(note 三态 + 排除统计 / 排除预算)。
  /// note 用 [Patch] 表达三态;两个 bool 用 `null` 表示不改。
  Transaction updatedMetadata({
    Patch<String>? note,
    bool? isExcludedFromStats,
    bool? isExcludedFromBudget,
  }) {
    return _copyWith(
      notePatch: note,
      isExcludedFromStats: isExcludedFromStats,
      isExcludedFromBudget: isExcludedFromBudget,
    );
  }

  Transaction updatedOwnership(TransactionOwnership ownership) {
    return _copyWith(ownership: ownership);
  }

  Transaction withOccurredAt(DateTime occurredAt) {
    return _copyWith(occurredAt: occurredAt);
  }

  Transaction _copyWith({
    int? id,
    int? rootTransactionId,
    BusinessPurpose? businessPurpose,
    DateTime? occurredAt,
    Money? primaryAmount,
    String? counterpartyName,
    Patch<String>? notePatch,
    int? parentTransactionId,
    int? reimbursementExpenseAccountId,
    MutationKind? mutationKind,
    int? mutationPreviousTransactionId,
    MutationReason? mutationReason,
    BusinessState? businessState,
    bool? isExcludedFromStats,
    bool? isExcludedFromBudget,
    SourceKind? sourceKind,
    TransactionOwnership? ownership,
    DateTime? createdAt,
    List<ReceiptDetail>? details,
    List<ReceiptEntry>? entries,
  }) {
    return Transaction._(
      id: id ?? _id,
      rootTransactionId: rootTransactionId ?? _rootTransactionId,
      businessPurpose: businessPurpose ?? this.businessPurpose,
      occurredAt: occurredAt ?? this.occurredAt,
      primaryAmount: primaryAmount ?? this.primaryAmount,
      counterpartyName: counterpartyName ?? this.counterpartyName,
      note: switch (notePatch) {
        null => note,
        PatchSet<String>(:final value) => value.isEmpty ? null : value,
        PatchClear<String>() => null,
      },
      parentTransactionId: parentTransactionId ?? this.parentTransactionId,
      reimbursementExpenseAccountId:
          reimbursementExpenseAccountId ?? this.reimbursementExpenseAccountId,
      mutationKind: mutationKind ?? this.mutationKind,
      mutationPreviousTransactionId:
          mutationPreviousTransactionId ?? this.mutationPreviousTransactionId,
      mutationReason: mutationReason ?? this.mutationReason,
      businessState: businessState ?? this.businessState,
      isExcludedFromStats: isExcludedFromStats ?? this.isExcludedFromStats,
      isExcludedFromBudget: isExcludedFromBudget ?? this.isExcludedFromBudget,
      sourceKind: sourceKind ?? this.sourceKind,
      ownership: ownership ?? this.ownership,
      createdAt: createdAt ?? this.createdAt,
      details: details ?? this.details,
      entries: entries ?? this.entries,
    );
  }
}
