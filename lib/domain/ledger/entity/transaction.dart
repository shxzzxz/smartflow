import '../../../core/money/money.dart';
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

  Transaction _copyWith({
    int? id,
    int? rootTransactionId,
    BusinessPurpose? businessPurpose,
    DateTime? occurredAt,
    Money? primaryAmount,
    String? counterpartyName,
    String? note,
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
      note: note ?? this.note,
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
