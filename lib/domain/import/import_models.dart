import 'dart:typed_data';

import '../../core/money/money.dart';
import '../../core/patch/patch.dart';

/// A supported external import source. The enum intentionally has one value in
/// the first release; adding a source must not change the Yimu semantics.
enum ImportSource { yimu }

enum ImportEntityKind { account, category }

enum ImportCategoryKind { income, expense }

enum ImportOperationKind {
  expense,
  income,
  transfer,
  refund,
  reimbursementAdvance,
  reimbursementReceipt,
  reimbursementClose,
  repayment,
  interestExpense,
  borrowing,
  openingBalance,
}

enum ImportIssueSeverity { fatal, blocking, warning }

/// Alias used by callers that describe parser problems as "problems".
typedef ImportProblemSeverity = ImportIssueSeverity;

class ImportIssue {
  const ImportIssue({
    required this.code,
    required this.message,
    required this.severity,
    this.rowNumber,
    this.fileRole,
  });

  final String code;
  final String message;
  final ImportIssueSeverity severity;
  final int? rowNumber;
  final YimuFileRole? fileRole;

  bool get isFatal => severity == ImportIssueSeverity.fatal;
  bool get isBlocking => severity == ImportIssueSeverity.blocking;
  bool get isWarning => severity == ImportIssueSeverity.warning;
}

class ImportFilePayload {
  ImportFilePayload({required this.name, required Uint8List bytes})
    : bytes = Uint8List.fromList(bytes);

  final String name;
  final Uint8List bytes;
}

class ImportBundle {
  ImportBundle({required Iterable<ImportFilePayload> files})
    : files = List.unmodifiable(files);

  final List<ImportFilePayload> files;
}

enum YimuFileRole { bill, transfer, debt }

class ImportSourceEntity {
  const ImportSourceEntity({
    required this.source,
    required this.kind,
    required this.sourceEntityKey,
    required this.displayName,
    this.categoryKind,
    this.isReviewPlaceholder = false,
  });

  final ImportSource source;
  final ImportEntityKind kind;
  final String sourceEntityKey;
  final String displayName;
  final ImportCategoryKind? categoryKind;
  final bool isReviewPlaceholder;
}

class ImportAccountReference {
  const ImportAccountReference._({
    required this.sourceEntityKey,
    required this.displayName,
    required this.isExplicitNone,
    required this.isUnresolved,
  });

  const ImportAccountReference.source({
    required String sourceEntityKey,
    required String displayName,
  }) : this._(
         sourceEntityKey: sourceEntityKey,
         displayName: displayName,
         isExplicitNone: false,
         isUnresolved: false,
       );

  const ImportAccountReference.explicitNone()
    : this._(
        sourceEntityKey: null,
        displayName: null,
        isExplicitNone: true,
        isUnresolved: false,
      );

  const ImportAccountReference.unresolved({
    String? sourceEntityKey,
    String? displayName,
  }) : this._(
         sourceEntityKey: sourceEntityKey,
         displayName: displayName,
         isExplicitNone: false,
         isUnresolved: true,
       );

  final String? sourceEntityKey;
  final String? displayName;
  final bool isExplicitNone;
  final bool isUnresolved;

  bool get needsMapping => sourceEntityKey != null;
}

class ImportCategoryReference {
  const ImportCategoryReference({
    required this.sourceEntityKey,
    required this.path,
    required this.kind,
  });

  final String sourceEntityKey;
  final String path;
  final ImportCategoryKind kind;
}

sealed class ImportTransactionDraft {
  const ImportTransactionDraft({
    required this.amount,
    required this.occurredAt,
    DateTime? postedAt,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
  }) : postedAt = postedAt ?? occurredAt;

  final Money amount;
  final DateTime occurredAt;
  final DateTime postedAt;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;

  ImportOperationKind get operationKind;

  Iterable<String> get sourceEntityKeys;
}

class ImportExpenseDraft extends ImportTransactionDraft {
  const ImportExpenseDraft({
    required super.amount,
    required this.paidFrom,
    required this.category,
    required super.occurredAt,
    super.postedAt,
    super.note,
    super.isExcludedFromStats,
    super.isExcludedFromBudget,
  });

  final ImportAccountReference paidFrom;
  final ImportCategoryReference category;

  @override
  ImportOperationKind get operationKind => ImportOperationKind.expense;

  @override
  Iterable<String> get sourceEntityKeys => [
    if (paidFrom.sourceEntityKey != null) paidFrom.sourceEntityKey!,
    category.sourceEntityKey,
  ];
}

class ImportIncomeDraft extends ImportTransactionDraft {
  const ImportIncomeDraft({
    required super.amount,
    required this.receiveAccount,
    required this.category,
    required super.occurredAt,
    super.postedAt,
    super.note,
    super.isExcludedFromStats,
    super.isExcludedFromBudget,
  });

  final ImportAccountReference receiveAccount;
  final ImportCategoryReference category;

  @override
  ImportOperationKind get operationKind => ImportOperationKind.income;

  @override
  Iterable<String> get sourceEntityKeys => [
    if (receiveAccount.sourceEntityKey != null) receiveAccount.sourceEntityKey!,
    category.sourceEntityKey,
  ];
}

class ImportRefundDraft extends ImportTransactionDraft {
  const ImportRefundDraft({
    required super.amount,
    required this.refundTo,
    required super.occurredAt,
    super.postedAt,
    super.note,
  });

  final ImportAccountReference refundTo;

  @override
  ImportOperationKind get operationKind => ImportOperationKind.refund;

  @override
  Iterable<String> get sourceEntityKeys => [
    if (refundTo.sourceEntityKey != null) refundTo.sourceEntityKey!,
  ];
}

class ImportReimbursementAdvanceDraft extends ImportTransactionDraft {
  const ImportReimbursementAdvanceDraft({
    required super.amount,
    required this.receivableAccount,
    required this.paidFrom,
    required this.category,
    required super.occurredAt,
    super.postedAt,
    super.note,
    super.isExcludedFromStats,
    super.isExcludedFromBudget,
  });

  final ImportAccountReference receivableAccount;
  final ImportAccountReference paidFrom;
  final ImportCategoryReference category;

  @override
  ImportOperationKind get operationKind =>
      ImportOperationKind.reimbursementAdvance;

  @override
  Iterable<String> get sourceEntityKeys => [
    if (receivableAccount.sourceEntityKey != null)
      receivableAccount.sourceEntityKey!,
    if (paidFrom.sourceEntityKey != null) paidFrom.sourceEntityKey!,
    category.sourceEntityKey,
  ];
}

class ImportReimbursementReceiptDraft extends ImportTransactionDraft {
  const ImportReimbursementReceiptDraft({
    required super.amount,
    required this.receivableAccount,
    required this.receiveAccount,
    required super.occurredAt,
    super.postedAt,
    super.note,
  });

  final ImportAccountReference receivableAccount;
  final ImportAccountReference receiveAccount;

  @override
  ImportOperationKind get operationKind =>
      ImportOperationKind.reimbursementReceipt;

  @override
  Iterable<String> get sourceEntityKeys => [
    if (receivableAccount.sourceEntityKey != null)
      receivableAccount.sourceEntityKey!,
    if (receiveAccount.sourceEntityKey != null) receiveAccount.sourceEntityKey!,
  ];
}

class ImportReimbursementCloseDraft extends ImportTransactionDraft {
  const ImportReimbursementCloseDraft({
    required this.actualReceivedAmount,
    required this.receivableAccount,
    required this.receiveAccount,
    required super.occurredAt,
    super.postedAt,
    super.note,
  }) : super(amount: actualReceivedAmount);

  final Money actualReceivedAmount;
  final ImportAccountReference receivableAccount;
  final ImportAccountReference receiveAccount;

  @override
  ImportOperationKind get operationKind =>
      ImportOperationKind.reimbursementClose;

  @override
  Iterable<String> get sourceEntityKeys => [
    if (receivableAccount.sourceEntityKey != null)
      receivableAccount.sourceEntityKey!,
    if (receiveAccount.sourceEntityKey != null) receiveAccount.sourceEntityKey!,
  ];
}

class ImportTransferDraft extends ImportTransactionDraft {
  const ImportTransferDraft({
    required super.amount,
    required this.fromAccount,
    required this.toAccount,
    this.feeAmount,
    required super.occurredAt,
    super.postedAt,
    super.note,
  });

  final ImportAccountReference fromAccount;
  final ImportAccountReference toAccount;
  final Money? feeAmount;

  @override
  ImportOperationKind get operationKind => ImportOperationKind.transfer;

  @override
  Iterable<String> get sourceEntityKeys => [
    if (fromAccount.sourceEntityKey != null) fromAccount.sourceEntityKey!,
    if (toAccount.sourceEntityKey != null) toAccount.sourceEntityKey!,
  ];
}

class ImportRepaymentDraft extends ImportTransactionDraft {
  ImportRepaymentDraft({
    required this.principal,
    required this.liabilityAccount,
    required this.paidFrom,
    this.interest,
    this.fee,
    required super.occurredAt,
    super.postedAt,
    super.note,
  }) : super(
         amount: principal + (interest ?? Money.zero()) + (fee ?? Money.zero()),
       );

  final Money principal;
  final Money? interest;
  final Money? fee;
  final ImportAccountReference liabilityAccount;
  final ImportAccountReference paidFrom;

  @override
  ImportOperationKind get operationKind => ImportOperationKind.repayment;

  @override
  Iterable<String> get sourceEntityKeys => [
    if (liabilityAccount.sourceEntityKey != null)
      liabilityAccount.sourceEntityKey!,
    if (paidFrom.sourceEntityKey != null) paidFrom.sourceEntityKey!,
  ];
}

class ImportInterestExpenseDraft extends ImportTransactionDraft {
  const ImportInterestExpenseDraft({
    required super.amount,
    required this.paidFrom,
    required super.occurredAt,
    super.postedAt,
    super.note,
  });

  final ImportAccountReference paidFrom;

  @override
  ImportOperationKind get operationKind => ImportOperationKind.interestExpense;

  @override
  Iterable<String> get sourceEntityKeys => [
    if (paidFrom.sourceEntityKey != null) paidFrom.sourceEntityKey!,
  ];
}

class ImportBorrowingDraft extends ImportTransactionDraft {
  const ImportBorrowingDraft({
    required super.amount,
    required this.liabilityAccount,
    required this.receiveAccount,
    required super.occurredAt,
    super.postedAt,
    super.note,
  });

  final ImportAccountReference liabilityAccount;
  final ImportAccountReference receiveAccount;

  @override
  ImportOperationKind get operationKind => ImportOperationKind.borrowing;

  @override
  Iterable<String> get sourceEntityKeys => [
    if (liabilityAccount.sourceEntityKey != null)
      liabilityAccount.sourceEntityKey!,
    if (receiveAccount.sourceEntityKey != null) receiveAccount.sourceEntityKey!,
  ];
}

class ImportOpeningBalanceDraft extends ImportTransactionDraft {
  const ImportOpeningBalanceDraft({
    required super.amount,
    required this.liabilityAccount,
    required super.occurredAt,
    super.postedAt,
    super.note,
  });

  final ImportAccountReference liabilityAccount;

  @override
  ImportOperationKind get operationKind => ImportOperationKind.openingBalance;

  @override
  Iterable<String> get sourceEntityKeys => [
    if (liabilityAccount.sourceEntityKey != null)
      liabilityAccount.sourceEntityKey!,
  ];
}

class ImportTransactionGroupDraft {
  ImportTransactionGroupDraft({
    required this.topLevel,
    Iterable<ImportTransactionDraft> children = const [],
    required this.sourceOperationFingerprint,
    required this.fingerprintVersion,
    this.sourceOperationKey,
    Iterable<ImportIssue> issues = const [],
  }) : children = List.unmodifiable(children),
       issues = List.unmodifiable(issues);

  final ImportTransactionDraft topLevel;
  final List<ImportTransactionDraft> children;
  final String? sourceOperationKey;
  final String sourceOperationFingerprint;
  final int fingerprintVersion;
  final List<ImportIssue> issues;

  Iterable<ImportTransactionDraft> get transactions sync* {
    yield topLevel;
    yield* children;
  }

  bool get hasBlockingIssues =>
      issues.any((issue) => issue.severity == ImportIssueSeverity.blocking);

  bool get hasWarnings =>
      issues.any((issue) => issue.severity == ImportIssueSeverity.warning);

  /// Returns a new group while preserving its source identity.  Review edits
  /// must never recalculate the fingerprint or operation key: those values
  /// describe the source facts before mapping and user adjustments.
  ImportTransactionGroupDraft copyWith({
    ImportTransactionDraft? topLevel,
    Iterable<ImportTransactionDraft>? children,
    Iterable<ImportIssue>? issues,
  }) {
    return ImportTransactionGroupDraft(
      topLevel: topLevel ?? this.topLevel,
      children: children ?? this.children,
      sourceOperationKey: sourceOperationKey,
      sourceOperationFingerprint: sourceOperationFingerprint,
      fingerprintVersion: fingerprintVersion,
      issues: issues ?? this.issues,
    );
  }
}

class ImportFilteredRecord {
  const ImportFilteredRecord({
    required this.reasonCode,
    required this.reason,
    required this.fileRole,
    this.rowNumber,
  });

  final String reasonCode;
  final String reason;
  final YimuFileRole fileRole;
  final int? rowNumber;
}

class ImportParseResult {
  ImportParseResult({
    required this.source,
    Iterable<ImportSourceEntity> sourceEntities = const [],
    Iterable<ImportTransactionGroupDraft> groups = const [],
    Iterable<ImportFilteredRecord> filteredRecords = const [],
    Iterable<ImportIssue> fatalIssues = const [],
  }) : sourceEntities = List.unmodifiable(sourceEntities),
       groups = List.unmodifiable(groups),
       filteredRecords = List.unmodifiable(filteredRecords),
       fatalIssues = List.unmodifiable(fatalIssues);

  final ImportSource source;
  final List<ImportSourceEntity> sourceEntities;
  final List<ImportTransactionGroupDraft> groups;
  final List<ImportFilteredRecord> filteredRecords;
  final List<ImportIssue> fatalIssues;

  List<ImportSourceEntity> get sourceAccounts => sourceEntities
      .where((entity) => entity.kind == ImportEntityKind.account)
      .toList(growable: false);

  List<ImportSourceEntity> get sourceCategories => sourceEntities
      .where((entity) => entity.kind == ImportEntityKind.category)
      .toList(growable: false);

  bool get hasFatalIssues => fatalIssues.isNotEmpty;

  ImportParseResult copyWith({
    ImportSource? source,
    Iterable<ImportSourceEntity>? sourceEntities,
    Iterable<ImportTransactionGroupDraft>? groups,
    Iterable<ImportFilteredRecord>? filteredRecords,
    Iterable<ImportIssue>? fatalIssues,
  }) {
    return ImportParseResult(
      source: source ?? this.source,
      sourceEntities: sourceEntities ?? this.sourceEntities,
      groups: groups ?? this.groups,
      filteredRecords: filteredRecords ?? this.filteredRecords,
      fatalIssues: fatalIssues ?? this.fatalIssues,
    );
  }
}

/// User-editable fields for one draft during import review.
///
/// A null scalar means "keep the parsed value". Nullable fields use [Patch]
/// so the review can explicitly clear a note or an optional fee/interest.
/// The operation kind and group structure are intentionally absent from this
/// object; callers cannot change them through the review API.
class ImportDraftEdit {
  const ImportDraftEdit({
    this.amount,
    this.occurredAt,
    this.postedAt,
    this.note,
    this.interest,
    this.fee,
    this.transferFee,
  });

  final Money? amount;
  final DateTime? occurredAt;
  final DateTime? postedAt;
  final Patch<String?>? note;
  final Patch<Money?>? interest;
  final Patch<Money?>? fee;
  final Patch<Money?>? transferFee;
}

/// Applies review-editable fields while retaining source references and
/// operation semantics.  Account/category changes are represented separately
/// by import mapping overrides, not by replacing source identity here.
ImportTransactionDraft applyImportDraftEdit(
  ImportTransactionDraft draft,
  ImportDraftEdit edit,
) {
  final occurredAt = edit.occurredAt ?? draft.occurredAt;
  final postedAt = edit.postedAt ?? draft.postedAt;
  final note = edit.note.applyTo(draft.note);
  switch (draft) {
    case ImportExpenseDraft draft:
      return ImportExpenseDraft(
        amount: edit.amount ?? draft.amount,
        paidFrom: draft.paidFrom,
        category: draft.category,
        occurredAt: occurredAt,
        postedAt: postedAt,
        note: note,
        isExcludedFromStats: draft.isExcludedFromStats,
        isExcludedFromBudget: draft.isExcludedFromBudget,
      );
    case ImportIncomeDraft draft:
      return ImportIncomeDraft(
        amount: edit.amount ?? draft.amount,
        receiveAccount: draft.receiveAccount,
        category: draft.category,
        occurredAt: occurredAt,
        postedAt: postedAt,
        note: note,
        isExcludedFromStats: draft.isExcludedFromStats,
        isExcludedFromBudget: draft.isExcludedFromBudget,
      );
    case ImportRefundDraft draft:
      return ImportRefundDraft(
        amount: edit.amount ?? draft.amount,
        refundTo: draft.refundTo,
        occurredAt: occurredAt,
        postedAt: postedAt,
        note: note,
      );
    case ImportReimbursementAdvanceDraft draft:
      return ImportReimbursementAdvanceDraft(
        amount: edit.amount ?? draft.amount,
        receivableAccount: draft.receivableAccount,
        paidFrom: draft.paidFrom,
        category: draft.category,
        occurredAt: occurredAt,
        postedAt: postedAt,
        note: note,
        isExcludedFromStats: draft.isExcludedFromStats,
        isExcludedFromBudget: draft.isExcludedFromBudget,
      );
    case ImportReimbursementReceiptDraft draft:
      return ImportReimbursementReceiptDraft(
        amount: edit.amount ?? draft.amount,
        receivableAccount: draft.receivableAccount,
        receiveAccount: draft.receiveAccount,
        occurredAt: occurredAt,
        postedAt: postedAt,
        note: note,
      );
    case ImportReimbursementCloseDraft draft:
      final amount = edit.amount ?? draft.actualReceivedAmount;
      return ImportReimbursementCloseDraft(
        actualReceivedAmount: amount,
        receivableAccount: draft.receivableAccount,
        receiveAccount: draft.receiveAccount,
        occurredAt: occurredAt,
        postedAt: postedAt,
        note: note,
      );
    case ImportTransferDraft draft:
      return ImportTransferDraft(
        amount: edit.amount ?? draft.amount,
        fromAccount: draft.fromAccount,
        toAccount: draft.toAccount,
        feeAmount:
            edit.transferFee?.applyTo(draft.feeAmount) ?? draft.feeAmount,
        occurredAt: occurredAt,
        postedAt: postedAt,
        note: note,
      );
    case ImportRepaymentDraft draft:
      return ImportRepaymentDraft(
        principal: edit.amount ?? draft.principal,
        liabilityAccount: draft.liabilityAccount,
        paidFrom: draft.paidFrom,
        interest: edit.interest?.applyTo(draft.interest) ?? draft.interest,
        fee: edit.fee?.applyTo(draft.fee) ?? draft.fee,
        occurredAt: occurredAt,
        postedAt: postedAt,
        note: note,
      );
    case ImportInterestExpenseDraft draft:
      return ImportInterestExpenseDraft(
        amount: edit.amount ?? draft.amount,
        paidFrom: draft.paidFrom,
        occurredAt: occurredAt,
        postedAt: postedAt,
        note: note,
      );
    case ImportBorrowingDraft draft:
      return ImportBorrowingDraft(
        amount: edit.amount ?? draft.amount,
        liabilityAccount: draft.liabilityAccount,
        receiveAccount: draft.receiveAccount,
        occurredAt: occurredAt,
        postedAt: postedAt,
        note: note,
      );
    case ImportOpeningBalanceDraft draft:
      return ImportOpeningBalanceDraft(
        amount: edit.amount ?? draft.amount,
        liabilityAccount: draft.liabilityAccount,
        occurredAt: occurredAt,
        postedAt: postedAt,
        note: note,
      );
  }
}
