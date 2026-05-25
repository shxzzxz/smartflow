import '../../../core/money/money.dart';
import '../ledger/ledger_rules.dart';
import '../ledger/post_receipt.dart';
import '../enums/accounting_enums.dart';
import 'transaction_ownership.dart';

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

  factory Transaction.create({
    required BusinessPurpose businessPurpose,
    required DateTime occurredAt,
    required Money primaryAmount,
    required List<ReceiptDetail> details,
    required List<ReceiptEntry> entries,
    int? rootTransactionId,
    int? parentTransactionId,
    int? reimbursementExpenseAccountId,
    String? counterpartyName,
    String? note,
    bool isExcludedFromStats = false,
    bool isExcludedFromBudget = false,
    SourceKind sourceKind = SourceKind.manual,
    TransactionOwnership? ownership,
    MutationKind mutationKind = MutationKind.original,
    BusinessState businessState = BusinessState.current,
    MutationReason? mutationReason,
    int? mutationPreviousTransactionId,
    DateTime? createdAt,
    bool allowNegativeAmounts = false,
  }) {
    _validateTransaction(
      businessPurpose: businessPurpose,
      primaryAmount: primaryAmount,
      details: details,
      entries: entries,
      allowNegativeAmounts: allowNegativeAmounts,
    );
    return Transaction._(
      id: null,
      rootTransactionId: rootTransactionId,
      businessPurpose: businessPurpose,
      occurredAt: occurredAt,
      primaryAmount: primaryAmount,
      counterpartyName: counterpartyName,
      note: note,
      parentTransactionId: parentTransactionId,
      reimbursementExpenseAccountId: reimbursementExpenseAccountId,
      mutationKind: mutationKind,
      mutationPreviousTransactionId: mutationPreviousTransactionId,
      mutationReason: mutationReason,
      businessState: businessState,
      isExcludedFromStats: isExcludedFromStats,
      isExcludedFromBudget: isExcludedFromBudget,
      sourceKind: sourceKind,
      ownership: ownership,
      createdAt: createdAt ?? DateTime.now(),
      details: List.unmodifiable(details),
      entries: List.unmodifiable(entries),
    );
  }

  factory Transaction.fromReceipt(
    PostReceipt receipt, {
    MutationKind mutationKind = MutationKind.original,
    BusinessState businessState = BusinessState.current,
    MutationReason? mutationReason,
    int? mutationPreviousTransactionId,
    bool allowNegativeAmounts = false,
  }) {
    return Transaction.create(
      businessPurpose: receipt.businessPurpose,
      occurredAt: receipt.occurredAt,
      primaryAmount: receipt.primaryAmount,
      details: receipt.details,
      entries: receipt.entries,
      rootTransactionId: receipt.rootTransactionId,
      parentTransactionId: receipt.parentTransactionId,
      reimbursementExpenseAccountId: receipt.reimbursementExpenseAccountId,
      counterpartyName: receipt.counterpartyName,
      note: receipt.note,
      isExcludedFromStats: receipt.isExcludedFromStats,
      isExcludedFromBudget: receipt.isExcludedFromBudget,
      sourceKind: receipt.sourceKind,
      ownership: receipt.ownership,
      mutationKind: mutationKind,
      businessState: businessState,
      mutationReason: mutationReason,
      mutationPreviousTransactionId: mutationPreviousTransactionId,
      allowNegativeAmounts: allowNegativeAmounts,
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

void _validateTransaction({
  required BusinessPurpose businessPurpose,
  required Money primaryAmount,
  required List<ReceiptDetail> details,
  required List<ReceiptEntry> entries,
  required bool allowNegativeAmounts,
}) {
  if (details.isEmpty) {
    throw const FormatException('A transaction must have at least one detail.');
  }
  if (entries.length < 2) {
    throw const FormatException(
      'A transaction must have at least two entries.',
    );
  }
  if ((!allowNegativeAmounts && primaryAmount.minorUnits <= 0) ||
      (allowNegativeAmounts && primaryAmount.minorUnits == 0)) {
    throw const FormatException('Primary amount has an invalid sign.');
  }
  for (final detail in details) {
    _validateAmountSign(
      detail.amount.minorUnits,
      allowNegativeAmounts: allowNegativeAmounts,
    );
    if (!detailTypeAllowedForPurpose(
      detailType: detail.type,
      businessPurpose: businessPurpose,
    )) {
      throw FormatException(
        '${detail.type.name} is not allowed for ${businessPurpose.name}.',
      );
    }
  }
  for (final entry in entries) {
    _validateAmountSign(
      entry.amount.minorUnits,
      allowNegativeAmounts: allowNegativeAmounts,
    );
  }
  if (!entriesAreBalanced(entries)) {
    throw const FormatException('Debit and credit entries must be balanced.');
  }
}

void _validateAmountSign(
  int amountMinor, {
  required bool allowNegativeAmounts,
}) {
  final valid = allowNegativeAmounts ? amountMinor < 0 : amountMinor > 0;
  if (!valid) {
    throw const FormatException('Transaction amount has an invalid sign.');
  }
}
