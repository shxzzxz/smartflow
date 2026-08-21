import '../import_models.dart';

/// The ledger role required by one import draft endpoint.
///
/// This is an import-domain concept rather than an application workflow
/// detail.  Keeping the matrix here makes review-time filtering and commit-time
/// validation use the same rules.
enum ImportTargetUsage {
  settlement,
  fund,
  liability,
  receivable,
  reimbursement,
  incomeCategory,
  expenseCategory,
}

class ImportTargetRequirement {
  const ImportTargetRequirement({
    required this.entityKind,
    required this.sourceEntityKey,
    required this.descriptors,
  });

  final ImportEntityKind entityKind;
  final String sourceEntityKey;
  final Set<ImportTargetDescriptor> descriptors;
}

/// Pure compatibility policy shared by import review and commit.
class ImportTargetCompatibilityPolicy {
  const ImportTargetCompatibilityPolicy._();

  static Set<ImportTargetDescriptor> descriptorsForUsage(
    ImportTargetUsage usage,
  ) {
    return switch (usage) {
      ImportTargetUsage.settlement => {
        ImportTargetDescriptor.fundAccount,
        ImportTargetDescriptor.payableAccount,
        ImportTargetDescriptor.creditAccount,
      },
      ImportTargetUsage.fund => {ImportTargetDescriptor.fundAccount},
      ImportTargetUsage.liability => {
        ImportTargetDescriptor.payableAccount,
        ImportTargetDescriptor.creditAccount,
        ImportTargetDescriptor.loanAccount,
      },
      ImportTargetUsage.receivable => {
        ImportTargetDescriptor.receivableAccount,
      },
      ImportTargetUsage.reimbursement => {
        ImportTargetDescriptor.reimbursementAccount,
      },
      ImportTargetUsage.incomeCategory => {
        ImportTargetDescriptor.incomeCategory,
      },
      ImportTargetUsage.expenseCategory => {
        ImportTargetDescriptor.expenseCategory,
      },
    };
  }

  static bool supportsUsage(
    ImportTargetDescriptor descriptor,
    ImportTargetUsage usage,
  ) {
    return descriptorsForUsage(usage).contains(descriptor);
  }

  /// Checks the source-side constraint in addition to its entity kind.
  static bool supportsEntity(
    ImportSourceEntity entity,
    ImportTargetDescriptor descriptor,
  ) {
    if (entity.hasTargetDescriptorConflict) return false;
    if (entity.allowedTargetDescriptors.isNotEmpty &&
        !entity.allowedTargetDescriptors.contains(descriptor)) {
      return false;
    }
    return switch (entity.kind) {
      ImportEntityKind.account => {
        ImportTargetDescriptor.fundAccount,
        ImportTargetDescriptor.reimbursementAccount,
        ImportTargetDescriptor.receivableAccount,
        ImportTargetDescriptor.payableAccount,
        ImportTargetDescriptor.creditAccount,
        ImportTargetDescriptor.loanAccount,
      }.contains(descriptor),
      ImportEntityKind.category => switch (entity.categoryKind) {
        ImportCategoryKind.income =>
          descriptor == ImportTargetDescriptor.incomeCategory,
        ImportCategoryKind.expense =>
          descriptor == ImportTargetDescriptor.expenseCategory,
        null => false,
      },
    };
  }

  static Iterable<ImportTargetRequirement> requirementsForDraft(
    ImportTransactionDraft draft,
  ) sync* {
    switch (draft) {
      case ImportExpenseDraft draft:
        yield* _account(
          draft.paidFrom.sourceEntityKey,
          ImportTargetUsage.settlement,
        );
        yield _category(
          draft.category.sourceEntityKey,
          ImportTargetUsage.expenseCategory,
        );
      case ImportIncomeDraft draft:
        yield* _account(
          draft.receiveAccount.sourceEntityKey,
          ImportTargetUsage.settlement,
        );
        yield _category(
          draft.category.sourceEntityKey,
          ImportTargetUsage.incomeCategory,
        );
      case ImportRefundDraft draft:
        yield* _account(
          draft.refundTo.sourceEntityKey,
          ImportTargetUsage.settlement,
        );
      case ImportReimbursementAdvanceDraft draft:
        yield* _account(
          draft.receivableAccount.sourceEntityKey,
          ImportTargetUsage.reimbursement,
        );
        yield* _account(
          draft.paidFrom.sourceEntityKey,
          ImportTargetUsage.settlement,
        );
        yield _category(
          draft.category.sourceEntityKey,
          ImportTargetUsage.expenseCategory,
        );
      case ImportReimbursementReceiptDraft draft:
        yield* _account(
          draft.receivableAccount.sourceEntityKey,
          ImportTargetUsage.reimbursement,
        );
        yield* _account(
          draft.receiveAccount.sourceEntityKey,
          ImportTargetUsage.settlement,
        );
      case ImportReimbursementCloseDraft draft:
        yield* _account(
          draft.receivableAccount.sourceEntityKey,
          ImportTargetUsage.reimbursement,
        );
        yield* _account(
          draft.receiveAccount.sourceEntityKey,
          ImportTargetUsage.settlement,
        );
      case ImportTransferDraft draft:
        yield* _account(
          draft.fromAccount.sourceEntityKey,
          ImportTargetUsage.fund,
        );
        yield* _account(
          draft.toAccount.sourceEntityKey,
          ImportTargetUsage.fund,
        );
      case ImportRepaymentDraft draft:
        yield* _account(
          draft.liabilityAccount.sourceEntityKey,
          ImportTargetUsage.liability,
        );
        yield* _account(draft.paidFrom.sourceEntityKey, ImportTargetUsage.fund);
      case ImportInterestExpenseDraft draft:
        yield* _account(draft.paidFrom.sourceEntityKey, ImportTargetUsage.fund);
      case ImportBorrowingDraft draft:
        yield* _account(
          draft.liabilityAccount.sourceEntityKey,
          ImportTargetUsage.liability,
        );
        yield* _account(
          draft.receiveAccount.sourceEntityKey,
          ImportTargetUsage.fund,
        );
      case ImportLendingDraft draft:
        yield* _account(
          draft.receivableAccount.sourceEntityKey,
          ImportTargetUsage.receivable,
        );
        yield* _account(draft.paidFrom.sourceEntityKey, ImportTargetUsage.fund);
      case ImportReceivableCollectionDraft draft:
        yield* _account(
          draft.receivableAccount.sourceEntityKey,
          ImportTargetUsage.receivable,
        );
        yield* _account(
          draft.receiveAccount.sourceEntityKey,
          ImportTargetUsage.fund,
        );
      case ImportOpeningBalanceDraft draft:
        yield* _account(
          draft.account.sourceEntityKey,
          draft.accountKind == ImportOpeningBalanceAccountKind.receivable
              ? ImportTargetUsage.receivable
              : ImportTargetUsage.liability,
        );
    }
  }

  static Iterable<ImportTargetRequirement> _account(
    String? sourceEntityKey,
    ImportTargetUsage usage,
  ) sync* {
    if (sourceEntityKey == null) return;
    yield ImportTargetRequirement(
      entityKind: ImportEntityKind.account,
      sourceEntityKey: sourceEntityKey,
      descriptors: descriptorsForUsage(usage),
    );
  }

  static ImportTargetRequirement _category(
    String sourceEntityKey,
    ImportTargetUsage usage,
  ) {
    return ImportTargetRequirement(
      entityKind: ImportEntityKind.category,
      sourceEntityKey: sourceEntityKey,
      descriptors: descriptorsForUsage(usage),
    );
  }
}
