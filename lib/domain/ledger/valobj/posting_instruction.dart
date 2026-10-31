import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import 'account_amount_allocation.dart';
import 'ledger_enum.dart';
import 'ledger_violation_reason.dart';
import 'transaction_ownership.dart';

sealed class PostingInstruction {
  const PostingInstruction();

  BusinessPurpose get businessPurpose;

  Set<String> get accountIds;
}

class ExpenseInstruction extends PostingInstruction {
  ExpenseInstruction({
    required this.amount,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyId,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
    this.sourceKind = SourceKind.manual,
    this.ownership,
  }) : categoryAllocations = List.unmodifiable(categoryAllocations),
       settlementAllocations = List.unmodifiable(settlementAllocations);

  final Money amount;
  final List<AccountAmountAllocation> categoryAllocations;
  final List<AccountAmountAllocation> settlementAllocations;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyId;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
  final SourceKind sourceKind;
  final TransactionOwnership? ownership;

  @override
  BusinessPurpose get businessPurpose => BusinessPurpose.dailyExpense;

  @override
  Set<String> get accountIds => {
    for (final allocation in categoryAllocations) allocation.accountId,
    for (final allocation in settlementAllocations) allocation.accountId,
  };

  ExpenseInstruction copyWith({
    Money? amount,
    List<AccountAmountAllocation>? categoryAllocations,
    List<AccountAmountAllocation>? settlementAllocations,
    DateTime? occurredAt,
    DateTime? postedAt,
    String? counterpartyId,
    String? note,
    bool? isExcludedFromStats,
    bool? isExcludedFromBudget,
    SourceKind? sourceKind,
    TransactionOwnership? ownership,
  }) {
    final nextAmount = amount ?? this.amount;
    return ExpenseInstruction(
      amount: nextAmount,
      categoryAllocations: patchAllocations(
        current: this.categoryAllocations,
        total: nextAmount,
        explicit: categoryAllocations,
      ),
      settlementAllocations: patchAllocations(
        current: this.settlementAllocations,
        total: nextAmount,
        explicit: settlementAllocations,
      ),
      occurredAt: occurredAt ?? this.occurredAt,
      postedAt: postedAt ?? this.postedAt,
      counterpartyId: counterpartyId ?? this.counterpartyId,
      note: note ?? this.note,
      isExcludedFromStats: isExcludedFromStats ?? this.isExcludedFromStats,
      isExcludedFromBudget: isExcludedFromBudget ?? this.isExcludedFromBudget,
      sourceKind: sourceKind ?? this.sourceKind,
      ownership: ownership ?? this.ownership,
    );
  }
}

class IncomeInstruction extends PostingInstruction {
  IncomeInstruction({
    required this.amount,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyId,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
    this.sourceKind = SourceKind.manual,
    this.ownership,
  }) : categoryAllocations = List.unmodifiable(categoryAllocations),
       settlementAllocations = List.unmodifiable(settlementAllocations);

  final Money amount;
  final List<AccountAmountAllocation> categoryAllocations;
  final List<AccountAmountAllocation> settlementAllocations;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyId;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
  final SourceKind sourceKind;
  final TransactionOwnership? ownership;

  @override
  BusinessPurpose get businessPurpose => BusinessPurpose.dailyIncome;

  @override
  Set<String> get accountIds => {
    for (final allocation in categoryAllocations) allocation.accountId,
    for (final allocation in settlementAllocations) allocation.accountId,
  };

  IncomeInstruction copyWith({
    Money? amount,
    List<AccountAmountAllocation>? categoryAllocations,
    List<AccountAmountAllocation>? settlementAllocations,
    DateTime? occurredAt,
    DateTime? postedAt,
    String? counterpartyId,
    String? note,
    bool? isExcludedFromStats,
    bool? isExcludedFromBudget,
    SourceKind? sourceKind,
    TransactionOwnership? ownership,
  }) {
    final nextAmount = amount ?? this.amount;
    return IncomeInstruction(
      amount: nextAmount,
      categoryAllocations: patchAllocations(
        current: this.categoryAllocations,
        total: nextAmount,
        explicit: categoryAllocations,
      ),
      settlementAllocations: patchAllocations(
        current: this.settlementAllocations,
        total: nextAmount,
        explicit: settlementAllocations,
      ),
      occurredAt: occurredAt ?? this.occurredAt,
      postedAt: postedAt ?? this.postedAt,
      counterpartyId: counterpartyId ?? this.counterpartyId,
      note: note ?? this.note,
      isExcludedFromStats: isExcludedFromStats ?? this.isExcludedFromStats,
      isExcludedFromBudget: isExcludedFromBudget ?? this.isExcludedFromBudget,
      sourceKind: sourceKind ?? this.sourceKind,
      ownership: ownership ?? this.ownership,
    );
  }
}

class AdvanceInstruction extends PostingInstruction {
  AdvanceInstruction({
    required this.amount,
    Money? advanceAmount,
    required this.receivableAccountId,
    required List<AccountAmountAllocation> categoryAllocations,
    List<AccountAmountAllocation> selfBorneAllocations = const [],
    required List<AccountAmountAllocation> settlementAllocations,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyId,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
    this.sourceKind = SourceKind.manual,
    this.ownership,
  }) : advanceAmount = advanceAmount ?? amount,
       categoryAllocations = List.unmodifiable(categoryAllocations),
       selfBorneAllocations = List.unmodifiable(selfBorneAllocations),
       settlementAllocations = List.unmodifiable(settlementAllocations);

  final Money amount;
  final Money advanceAmount;
  final String receivableAccountId;
  final List<AccountAmountAllocation> categoryAllocations;
  final List<AccountAmountAllocation> selfBorneAllocations;
  final List<AccountAmountAllocation> settlementAllocations;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyId;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
  final SourceKind sourceKind;
  final TransactionOwnership? ownership;

  @override
  BusinessPurpose get businessPurpose => BusinessPurpose.advance;

  @override
  Set<String> get accountIds => {
    receivableAccountId,
    for (final allocation in categoryAllocations) allocation.accountId,
    for (final allocation in selfBorneAllocations) allocation.accountId,
    for (final allocation in settlementAllocations) allocation.accountId,
  };

  AdvanceInstruction copyWith({
    Money? amount,
    Money? advanceAmount,
    String? receivableAccountId,
    List<AccountAmountAllocation>? categoryAllocations,
    List<AccountAmountAllocation>? selfBorneAllocations,
    List<AccountAmountAllocation>? settlementAllocations,
    DateTime? occurredAt,
    DateTime? postedAt,
    String? counterpartyId,
    String? note,
    bool? isExcludedFromStats,
    bool? isExcludedFromBudget,
    SourceKind? sourceKind,
    TransactionOwnership? ownership,
  }) {
    final nextAmount = amount ?? this.amount;
    final nextAdvanceAmount = advanceAmount ?? this.advanceAmount;
    final selfBorneAmount = nextAmount - nextAdvanceAmount;
    return AdvanceInstruction(
      amount: nextAmount,
      advanceAmount: nextAdvanceAmount,
      receivableAccountId: receivableAccountId ?? this.receivableAccountId,
      categoryAllocations: patchAllocations(
        current: this.categoryAllocations,
        total: nextAmount,
        explicit: categoryAllocations,
      ),
      selfBorneAllocations: patchAllocations(
        current: this.selfBorneAllocations,
        total: selfBorneAmount,
        explicit: selfBorneAllocations,
      ),
      settlementAllocations: patchAllocations(
        current: this.settlementAllocations,
        total: nextAmount,
        explicit: settlementAllocations,
      ),
      occurredAt: occurredAt ?? this.occurredAt,
      postedAt: postedAt ?? this.postedAt,
      counterpartyId: counterpartyId ?? this.counterpartyId,
      note: note ?? this.note,
      isExcludedFromStats: isExcludedFromStats ?? this.isExcludedFromStats,
      isExcludedFromBudget: isExcludedFromBudget ?? this.isExcludedFromBudget,
      sourceKind: sourceKind ?? this.sourceKind,
      ownership: ownership ?? this.ownership,
    );
  }
}

class RefundInstruction {
  RefundInstruction({
    required this.parentTransactionId,
    required this.amount,
    required List<AccountAmountAllocation> categoryAllocations,
    List<AccountAmountAllocation> selfBorneAllocations = const [],
    required List<AccountAmountAllocation> settlementAllocations,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyId,
    this.note,
  }) : categoryAllocations = List.unmodifiable(categoryAllocations),
       selfBorneAllocations = List.unmodifiable(selfBorneAllocations),
       settlementAllocations = List.unmodifiable(settlementAllocations);

  final String parentTransactionId;
  final Money amount;
  final List<AccountAmountAllocation> categoryAllocations;
  final List<AccountAmountAllocation> selfBorneAllocations;
  final List<AccountAmountAllocation> settlementAllocations;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyId;
  final String? note;
}

class AdvanceSettlementInstruction {
  AdvanceSettlementInstruction({
    required this.advanceTransactionId,
    required this.actualReceivedAmount,
    required this.receivableAccountId,
    required List<AccountAmountAllocation> settlementAllocations,
    required List<AccountAmountAllocation> gapExpenseAllocations,
    this.shortfallKind = AdvanceShortfallKind.selfBorne,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyId,
    this.note,
  }) : ownership = null,
       isExcludedFromStats = false,
       isExcludedFromBudget = false,
       settlementAllocations = List.unmodifiable(settlementAllocations),
       gapExpenseAllocations = List.unmodifiable(gapExpenseAllocations);

  final String advanceTransactionId;
  final Money actualReceivedAmount;
  final String receivableAccountId;
  final List<AccountAmountAllocation> settlementAllocations;
  final List<AccountAmountAllocation> gapExpenseAllocations;
  final AdvanceShortfallKind shortfallKind;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyId;
  final String? note;
  final TransactionOwnership? ownership;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
}

class TransferInstruction extends PostingInstruction {
  const TransferInstruction({
    required this.amount,
    required this.fromAccountId,
    required this.toAccountId,
    required this.occurredAt,
    this.postedAt,
    this.feeAmount,
    this.counterpartyId,
    this.note,
    this.ownership,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
    this.sourceKind = SourceKind.manual,
  });

  final Money amount;
  final String fromAccountId;
  final String toAccountId;
  final Money? feeAmount;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyId;
  final String? note;
  final TransactionOwnership? ownership;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
  final SourceKind sourceKind;

  @override
  BusinessPurpose get businessPurpose => BusinessPurpose.transfer;

  @override
  Set<String> get accountIds => {fromAccountId, toAccountId};

  TransferInstruction copyWith({
    Money? amount,
    String? fromAccountId,
    String? toAccountId,
    Money? feeAmount,
    DateTime? occurredAt,
    DateTime? postedAt,
    String? counterpartyId,
    String? note,
    TransactionOwnership? ownership,
    bool? isExcludedFromStats,
    bool? isExcludedFromBudget,
    SourceKind? sourceKind,
  }) {
    return TransferInstruction(
      amount: amount ?? this.amount,
      fromAccountId: fromAccountId ?? this.fromAccountId,
      toAccountId: toAccountId ?? this.toAccountId,
      feeAmount: feeAmount ?? this.feeAmount,
      occurredAt: occurredAt ?? this.occurredAt,
      postedAt: postedAt ?? this.postedAt,
      counterpartyId: counterpartyId ?? this.counterpartyId,
      note: note ?? this.note,
      ownership: ownership ?? this.ownership,
      isExcludedFromStats: isExcludedFromStats ?? this.isExcludedFromStats,
      isExcludedFromBudget: isExcludedFromBudget ?? this.isExcludedFromBudget,
      sourceKind: sourceKind ?? this.sourceKind,
    );
  }
}

class AdvanceCollectionInstruction {
  AdvanceCollectionInstruction({
    required this.advanceTransactionId,
    required this.amount,
    required this.receivableAccountId,
    required List<AccountAmountAllocation> settlementAllocations,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyId,
    this.note,
  }) : ownership = null,
       isExcludedFromStats = false,
       isExcludedFromBudget = false,
       settlementAllocations = List.unmodifiable(settlementAllocations);

  final String advanceTransactionId;
  final Money amount;
  final String receivableAccountId;
  final List<AccountAmountAllocation> settlementAllocations;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyId;
  final String? note;
  final TransactionOwnership? ownership;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
}

class RepaymentInstruction extends PostingInstruction {
  const RepaymentInstruction({
    required this.principal,
    required this.liabilityAccountId,
    required this.paidFromAccountId,
    required this.occurredAt,
    this.postedAt,
    this.interest,
    this.fee,
    this.discount,
    this.counterpartyId,
    this.note,
    this.ownership,
    this.sourceKind = SourceKind.manual,
  });

  final Money principal;
  final Money? interest;
  final Money? fee;
  final Money? discount;
  final String liabilityAccountId;
  final String paidFromAccountId;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyId;
  final String? note;
  final TransactionOwnership? ownership;
  final SourceKind sourceKind;

  @override
  BusinessPurpose get businessPurpose => BusinessPurpose.debtRepayment;

  @override
  Set<String> get accountIds => {liabilityAccountId, paidFromAccountId};

  RepaymentInstruction copyWith({
    Money? principal,
    Money? interest,
    Money? fee,
    Money? discount,
    String? liabilityAccountId,
    String? paidFromAccountId,
    DateTime? occurredAt,
    DateTime? postedAt,
    String? counterpartyId,
    String? note,
    TransactionOwnership? ownership,
    SourceKind? sourceKind,
  }) {
    return RepaymentInstruction(
      principal: principal ?? this.principal,
      interest: interest ?? this.interest,
      fee: fee ?? this.fee,
      discount: discount ?? this.discount,
      liabilityAccountId: liabilityAccountId ?? this.liabilityAccountId,
      paidFromAccountId: paidFromAccountId ?? this.paidFromAccountId,
      occurredAt: occurredAt ?? this.occurredAt,
      postedAt: postedAt ?? this.postedAt,
      counterpartyId: counterpartyId ?? this.counterpartyId,
      note: note ?? this.note,
      ownership: ownership ?? this.ownership,
      sourceKind: sourceKind ?? this.sourceKind,
    );
  }
}

class BorrowingInstruction extends PostingInstruction {
  const BorrowingInstruction({
    required this.amount,
    required this.liabilityAccountId,
    required this.receiveAccountId,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyId,
    this.note,
    this.ownership,
    this.sourceKind = SourceKind.manual,
  });

  final Money amount;
  final String liabilityAccountId;
  final String receiveAccountId;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyId;
  final String? note;
  final TransactionOwnership? ownership;
  final SourceKind sourceKind;

  @override
  BusinessPurpose get businessPurpose => BusinessPurpose.borrowing;

  @override
  Set<String> get accountIds => {liabilityAccountId, receiveAccountId};

  BorrowingInstruction copyWith({
    Money? amount,
    String? liabilityAccountId,
    String? receiveAccountId,
    DateTime? occurredAt,
    DateTime? postedAt,
    String? counterpartyId,
    String? note,
    TransactionOwnership? ownership,
    SourceKind? sourceKind,
  }) {
    return BorrowingInstruction(
      amount: amount ?? this.amount,
      liabilityAccountId: liabilityAccountId ?? this.liabilityAccountId,
      receiveAccountId: receiveAccountId ?? this.receiveAccountId,
      occurredAt: occurredAt ?? this.occurredAt,
      postedAt: postedAt ?? this.postedAt,
      counterpartyId: counterpartyId ?? this.counterpartyId,
      note: note ?? this.note,
      ownership: ownership ?? this.ownership,
      sourceKind: sourceKind ?? this.sourceKind,
    );
  }
}

class LendingInstruction extends PostingInstruction {
  const LendingInstruction({
    required this.amount,
    required this.receivableAccountId,
    required this.paidFromAccountId,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyId,
    this.note,
    this.sourceKind = SourceKind.manual,
  });

  final Money amount;
  final String receivableAccountId;
  final String paidFromAccountId;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyId;
  final String? note;
  final SourceKind sourceKind;

  @override
  BusinessPurpose get businessPurpose => BusinessPurpose.lending;

  @override
  Set<String> get accountIds => {receivableAccountId, paidFromAccountId};
}

class ReceivableCollectionInstruction extends PostingInstruction {
  const ReceivableCollectionInstruction({
    required this.principal,
    required this.receivableAccountId,
    required this.receiveAccountId,
    required this.occurredAt,
    this.interest = const Money(minorUnits: 0),
    this.postedAt,
    this.counterpartyId,
    this.note,
    this.sourceKind = SourceKind.manual,
  });

  final Money principal;
  final Money interest;
  final String receivableAccountId;
  final String receiveAccountId;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyId;
  final String? note;
  final SourceKind sourceKind;

  @override
  BusinessPurpose get businessPurpose => BusinessPurpose.receivableCollection;

  @override
  Set<String> get accountIds => {receivableAccountId, receiveAccountId};
}

class BadDebtInstruction extends PostingInstruction {
  const BadDebtInstruction({
    required this.amount,
    required this.receivableAccountId,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyId,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
    this.sourceKind = SourceKind.manual,
  });

  final Money amount;
  final String receivableAccountId;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyId;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
  final SourceKind sourceKind;

  @override
  BusinessPurpose get businessPurpose => BusinessPurpose.badDebt;

  @override
  Set<String> get accountIds => {receivableAccountId};
}

class DebtReliefInstruction extends PostingInstruction {
  const DebtReliefInstruction({
    required this.amount,
    required this.liabilityAccountId,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyId,
    this.note,
    this.isExcludedFromStats = false,
    this.sourceKind = SourceKind.manual,
  });

  final Money amount;
  final String liabilityAccountId;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyId;
  final String? note;
  final bool isExcludedFromStats;
  final SourceKind sourceKind;

  @override
  BusinessPurpose get businessPurpose => BusinessPurpose.debtRelief;

  @override
  Set<String> get accountIds => {liabilityAccountId};
}

class OpeningBalanceInstruction {
  const OpeningBalanceInstruction({
    required this.accountId,
    required this.amount,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyId,
    this.note,
    this.sourceKind = SourceKind.manual,
  });

  final String accountId;
  final Money amount;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyId;
  final String? note;
  final SourceKind sourceKind;
}

class BalanceAdjustmentInstruction {
  const BalanceAdjustmentInstruction({
    required this.accountId,
    required this.targetBalance,
    required this.occurredAt,
    this.counterpartyId,
    this.note,
  });

  final String accountId;
  final Money targetBalance;
  final DateTime occurredAt;
  final String? counterpartyId;
  final String? note;
}

class EditParentTransactionInstruction {
  const EditParentTransactionInstruction({
    required this.transactionId,
    required this.editPatch,
    this.refundSelfBorneAllocations = const {},
    this.occurredAt,
    this.counterpartyId,
    this.note,
    this.isExcludedFromStats,
    this.isExcludedFromBudget,
  });

  final String transactionId;
  final PostingEditPatch editPatch;
  final Map<String, List<AccountAmountAllocation>> refundSelfBorneAllocations;
  final DateTime? occurredAt;
  final Patch<String?>? counterpartyId;
  final Patch<String?>? note;
  final bool? isExcludedFromStats;
  final bool? isExcludedFromBudget;
}

class EditRefundTransactionInstruction {
  const EditRefundTransactionInstruction({
    required this.transactionId,
    required this.editPatch,
    this.occurredAt,
    this.counterpartyId,
    this.note,
  });

  final String transactionId;
  final RefundEditPatch editPatch;
  final DateTime? occurredAt;
  final Patch<String?>? counterpartyId;
  final Patch<String?>? note;
}

class EditAdvanceCollectionTransactionInstruction {
  const EditAdvanceCollectionTransactionInstruction({
    required this.transactionId,
    this.amount,
    this.receivableAccountId,
    this.ownership,
    this.settlementAllocations,
    this.occurredAt,
    this.counterpartyId,
    this.note,
  });

  final String transactionId;
  final Money? amount;
  final String? receivableAccountId;
  final TransactionOwnership? ownership;
  final List<AccountAmountAllocation>? settlementAllocations;
  final DateTime? occurredAt;
  final Patch<String?>? counterpartyId;
  final Patch<String?>? note;
}

class EditAdvanceSettlementTransactionInstruction {
  const EditAdvanceSettlementTransactionInstruction({
    required this.transactionId,
    this.actualReceivedAmount,
    this.receivableAccountId,
    this.ownership,
    this.settlementAllocations,
    this.gapExpenseAllocations,
    this.shortfallKind,
    this.occurredAt,
    this.counterpartyId,
    this.note,
  });

  final String transactionId;
  final Money? actualReceivedAmount;
  final String? receivableAccountId;
  final TransactionOwnership? ownership;
  final List<AccountAmountAllocation>? settlementAllocations;
  final List<AccountAmountAllocation>? gapExpenseAllocations;
  final AdvanceShortfallKind? shortfallKind;
  final DateTime? occurredAt;
  final Patch<String?>? counterpartyId;
  final Patch<String?>? note;
}

class CancelTransactionInstruction {
  const CancelTransactionInstruction({required this.transactionId});

  final String transactionId;
}

class UpdateTransactionBasicInfoInstruction {
  const UpdateTransactionBasicInfoInstruction({
    required this.transactionId,
    this.occurredAt,
    this.postedAt,
    this.counterpartyId,
    this.note,
  });

  final String transactionId;
  final DateTime? occurredAt;
  final DateTime? postedAt;
  final Patch<String?>? counterpartyId;
  final Patch<String?>? note;
}

class UpdateTransactionReportingFlagInstruction {
  const UpdateTransactionReportingFlagInstruction({
    required this.transactionId,
    this.isExcludedFromStats,
    this.isExcludedFromBudget,
  });

  final String transactionId;
  final bool? isExcludedFromStats;
  final bool? isExcludedFromBudget;
}

class UpdateTransactionOwnershipInstruction {
  const UpdateTransactionOwnershipInstruction({
    required this.transactionId,
    required this.ownership,
  });

  final String transactionId;
  final TransactionOwnership ownership;
}

sealed class PostingEditPatch {
  const PostingEditPatch();

  BusinessPurpose get targetPurpose;

  PostingInstruction applyTo(PostingInstruction current);
}

class CategoryReplacementEditPatch extends PostingEditPatch {
  const CategoryReplacementEditPatch({
    required this.businessPurpose,
    required this.sourceCategoryId,
    required this.targetCategoryId,
  });

  final BusinessPurpose businessPurpose;
  final String sourceCategoryId;
  final String targetCategoryId;

  @override
  BusinessPurpose get targetPurpose => businessPurpose;

  @override
  PostingInstruction applyTo(PostingInstruction current) {
    if (current is AdvanceInstruction) {
      return current.copyWith(
        categoryAllocations: replaceAllocationAccount(
          allocations: current.categoryAllocations,
          sourceAccountId: sourceCategoryId,
          targetAccountId: targetCategoryId,
        ),
        selfBorneAllocations: replaceAllocationAccount(
          allocations: current.selfBorneAllocations,
          sourceAccountId: sourceCategoryId,
          targetAccountId: targetCategoryId,
        ),
      );
    }
    final allocations = switch (current) {
      ExpenseInstruction instruction => instruction.categoryAllocations,
      IncomeInstruction instruction => instruction.categoryAllocations,
      _ => null,
    };
    if (allocations != null) {
      final replaced = replaceAllocationAccount(
        allocations: allocations,
        sourceAccountId: sourceCategoryId,
        targetAccountId: targetCategoryId,
      );
      return switch (current) {
        ExpenseInstruction instruction => instruction.copyWith(
          categoryAllocations: replaced,
        ),
        IncomeInstruction instruction => instruction.copyWith(
          categoryAllocations: replaced,
        ),
        _ => throw StateError('Unreachable category replacement source.'),
      };
    }
    return LedgerViolationReason.unsupportedEditSource.throwException(
      message: 'This transaction does not reference the source category.',
    );
  }
}

class ExpenseEditPatch extends PostingEditPatch {
  const ExpenseEditPatch({
    this.amount,
    this.categoryAllocations,
    this.settlementAllocations,
  });

  final Money? amount;
  final List<AccountAmountAllocation>? categoryAllocations;
  final List<AccountAmountAllocation>? settlementAllocations;

  @override
  BusinessPurpose get targetPurpose => BusinessPurpose.dailyExpense;

  @override
  ExpenseInstruction applyTo(PostingInstruction current) {
    if (current is ExpenseInstruction) {
      return current.copyWith(
        amount: amount,
        categoryAllocations: categoryAllocations,
        settlementAllocations: settlementAllocations,
      );
    }
    if (current is AdvanceInstruction) {
      final nextAmount = amount ?? current.amount;
      return ExpenseInstruction(
        amount: nextAmount,
        categoryAllocations: patchAllocations(
          current: current.categoryAllocations,
          total: nextAmount,
          explicit: categoryAllocations,
        ),
        settlementAllocations: patchAllocations(
          current: current.settlementAllocations,
          total: nextAmount,
          explicit: settlementAllocations,
        ),
        occurredAt: current.occurredAt,
        postedAt: current.postedAt,
        counterpartyId: current.counterpartyId,
        note: current.note,
        isExcludedFromStats: current.isExcludedFromStats,
        isExcludedFromBudget: current.isExcludedFromBudget,
        sourceKind: current.sourceKind,
        ownership: current.ownership,
      );
    }
    return LedgerViolationReason.unsupportedEditSource.throwException(
      message: 'This transaction cannot be edited as an expense.',
    );
  }
}

class IncomeEditPatch extends PostingEditPatch {
  const IncomeEditPatch({
    this.amount,
    this.categoryAllocations,
    this.settlementAllocations,
  });

  final Money? amount;
  final List<AccountAmountAllocation>? categoryAllocations;
  final List<AccountAmountAllocation>? settlementAllocations;

  @override
  BusinessPurpose get targetPurpose => BusinessPurpose.dailyIncome;

  @override
  IncomeInstruction applyTo(PostingInstruction current) {
    if (current is IncomeInstruction) {
      return current.copyWith(
        amount: amount,
        categoryAllocations: categoryAllocations,
        settlementAllocations: settlementAllocations,
      );
    }
    return LedgerViolationReason.unsupportedEditSource.throwException(
      message: 'This transaction cannot be edited as an income.',
    );
  }
}

class TransferEditPatch extends PostingEditPatch {
  const TransferEditPatch({
    this.amount,
    this.fromAccountId,
    this.toAccountId,
    this.feeAmount,
  });

  final Money? amount;
  final String? fromAccountId;
  final String? toAccountId;

  /// `null` 表示不修改；零金额表示无手续费。
  final Money? feeAmount;

  @override
  BusinessPurpose get targetPurpose => BusinessPurpose.transfer;

  @override
  TransferInstruction applyTo(PostingInstruction current) {
    if (current is TransferInstruction) {
      return TransferInstruction(
        amount: amount ?? current.amount,
        fromAccountId: fromAccountId ?? current.fromAccountId,
        toAccountId: toAccountId ?? current.toAccountId,
        feeAmount: feeAmount ?? current.feeAmount,
        occurredAt: current.occurredAt,
        postedAt: current.postedAt,
        counterpartyId: current.counterpartyId,
        note: current.note,
        ownership: current.ownership,
        isExcludedFromStats: current.isExcludedFromStats,
        isExcludedFromBudget: current.isExcludedFromBudget,
        sourceKind: current.sourceKind,
      );
    }
    return LedgerViolationReason.unsupportedEditSource.throwException(
      message: 'This transaction cannot be edited as a transfer.',
    );
  }
}

class AdvanceEditPatch extends PostingEditPatch {
  const AdvanceEditPatch({
    this.amount,
    this.advanceAmount,
    this.receivableAccountId,
    this.ownership,
    this.categoryAllocations,
    this.selfBorneAllocations,
    this.settlementAllocations,
  });

  final Money? amount;
  final Money? advanceAmount;
  final String? receivableAccountId;
  final TransactionOwnership? ownership;
  final List<AccountAmountAllocation>? categoryAllocations;
  final List<AccountAmountAllocation>? selfBorneAllocations;
  final List<AccountAmountAllocation>? settlementAllocations;

  @override
  BusinessPurpose get targetPurpose => BusinessPurpose.advance;

  @override
  AdvanceInstruction applyTo(PostingInstruction current) {
    if (current is AdvanceInstruction) {
      return current.copyWith(
        amount: amount,
        advanceAmount: advanceAmount,
        receivableAccountId: receivableAccountId,
        ownership: ownership,
        categoryAllocations: categoryAllocations,
        selfBorneAllocations: selfBorneAllocations,
        settlementAllocations: settlementAllocations,
      );
    }
    if (current is ExpenseInstruction) {
      final receivable = receivableAccountId;
      if (receivable == null) {
        return LedgerViolationReason.advanceReceivableRequired.throwException();
      }
      final nextAmount = amount ?? current.amount;
      final nextAdvanceAmount = advanceAmount ?? nextAmount;
      final selfBorneAmount = nextAmount - nextAdvanceAmount;
      return AdvanceInstruction(
        amount: nextAmount,
        advanceAmount: nextAdvanceAmount,
        receivableAccountId: receivable,
        categoryAllocations: patchAllocations(
          current: current.categoryAllocations,
          total: nextAmount,
          explicit: categoryAllocations,
        ),
        selfBorneAllocations: patchAllocations(
          current: const [],
          total: selfBorneAmount,
          explicit: selfBorneAllocations,
        ),
        settlementAllocations: patchAllocations(
          current: current.settlementAllocations,
          total: nextAmount,
          explicit: settlementAllocations,
        ),
        occurredAt: current.occurredAt,
        postedAt: current.postedAt,
        counterpartyId: current.counterpartyId,
        note: current.note,
        isExcludedFromStats: current.isExcludedFromStats,
        isExcludedFromBudget: current.isExcludedFromBudget,
        sourceKind: current.sourceKind,
        ownership: ownership ?? current.ownership,
      );
    }
    return LedgerViolationReason.unsupportedEditSource.throwException(
      message: 'This transaction cannot be edited as an advance.',
    );
  }
}

class BorrowingEditPatch extends PostingEditPatch {
  const BorrowingEditPatch({
    this.amount,
    this.liabilityAccountId,
    this.receiveAccountId,
  });

  final Money? amount;
  final String? liabilityAccountId;
  final String? receiveAccountId;

  @override
  BusinessPurpose get targetPurpose => BusinessPurpose.borrowing;

  @override
  BorrowingInstruction applyTo(PostingInstruction current) {
    if (current is BorrowingInstruction) {
      return current.copyWith(
        amount: amount,
        liabilityAccountId: liabilityAccountId,
        receiveAccountId: receiveAccountId,
      );
    }
    return LedgerViolationReason.unsupportedEditSource.throwException(
      message: 'This transaction cannot be edited as borrowing.',
    );
  }
}

class RepaymentEditPatch extends PostingEditPatch {
  const RepaymentEditPatch({
    this.principal,
    this.interest,
    this.fee,
    this.discount,
    this.liabilityAccountId,
    this.paidFromAccountId,
  });

  final Money? principal;
  final Patch<Money?>? interest;
  final Patch<Money?>? fee;
  final Patch<Money?>? discount;
  final String? liabilityAccountId;
  final String? paidFromAccountId;

  @override
  BusinessPurpose get targetPurpose => BusinessPurpose.debtRepayment;

  @override
  RepaymentInstruction applyTo(PostingInstruction current) {
    if (current is RepaymentInstruction) {
      return RepaymentInstruction(
        principal: principal ?? current.principal,
        interest: _applyPatch(interest, current.interest),
        fee: _applyPatch(fee, current.fee),
        discount: _applyPatch(discount, current.discount),
        liabilityAccountId: liabilityAccountId ?? current.liabilityAccountId,
        paidFromAccountId: paidFromAccountId ?? current.paidFromAccountId,
        occurredAt: current.occurredAt,
        postedAt: current.postedAt,
        counterpartyId: current.counterpartyId,
        note: current.note,
        ownership: current.ownership,
        sourceKind: current.sourceKind,
      );
    }
    return LedgerViolationReason.unsupportedEditSource.throwException(
      message: 'This transaction cannot be edited as repayment.',
    );
  }
}

class LendingEditPatch extends PostingEditPatch {
  const LendingEditPatch({
    this.amount,
    this.receivableAccountId,
    this.paidFromAccountId,
  });
  final Money? amount;
  final String? receivableAccountId;
  final String? paidFromAccountId;
  @override
  BusinessPurpose get targetPurpose => BusinessPurpose.lending;
  @override
  LendingInstruction applyTo(PostingInstruction current) {
    if (current is! LendingInstruction) {
      return LedgerViolationReason.unsupportedEditSource.throwException();
    }
    return LendingInstruction(
      amount: amount ?? current.amount,
      receivableAccountId: receivableAccountId ?? current.receivableAccountId,
      paidFromAccountId: paidFromAccountId ?? current.paidFromAccountId,
      occurredAt: current.occurredAt,
      postedAt: current.postedAt,
      counterpartyId: current.counterpartyId,
      note: current.note,
      sourceKind: current.sourceKind,
    );
  }
}

class ReceivableCollectionEditPatch extends PostingEditPatch {
  const ReceivableCollectionEditPatch({
    this.principal,
    this.interest,
    this.receivableAccountId,
    this.receiveAccountId,
  });
  final Money? principal;
  final Money? interest;
  final String? receivableAccountId;
  final String? receiveAccountId;
  @override
  BusinessPurpose get targetPurpose => BusinessPurpose.receivableCollection;
  @override
  ReceivableCollectionInstruction applyTo(PostingInstruction current) {
    if (current is! ReceivableCollectionInstruction) {
      return LedgerViolationReason.unsupportedEditSource.throwException();
    }
    return ReceivableCollectionInstruction(
      principal: principal ?? current.principal,
      interest: interest ?? current.interest,
      receivableAccountId: receivableAccountId ?? current.receivableAccountId,
      receiveAccountId: receiveAccountId ?? current.receiveAccountId,
      occurredAt: current.occurredAt,
      postedAt: current.postedAt,
      counterpartyId: current.counterpartyId,
      note: current.note,
      sourceKind: current.sourceKind,
    );
  }
}

class BadDebtEditPatch extends PostingEditPatch {
  const BadDebtEditPatch({this.amount, this.receivableAccountId});
  final Money? amount;
  final String? receivableAccountId;
  @override
  BusinessPurpose get targetPurpose => BusinessPurpose.badDebt;
  @override
  BadDebtInstruction applyTo(PostingInstruction current) {
    if (current is! BadDebtInstruction) {
      return LedgerViolationReason.unsupportedEditSource.throwException();
    }
    return BadDebtInstruction(
      amount: amount ?? current.amount,
      receivableAccountId: receivableAccountId ?? current.receivableAccountId,
      occurredAt: current.occurredAt,
      postedAt: current.postedAt,
      counterpartyId: current.counterpartyId,
      note: current.note,
      isExcludedFromStats: current.isExcludedFromStats,
      isExcludedFromBudget: current.isExcludedFromBudget,
      sourceKind: current.sourceKind,
    );
  }
}

class DebtReliefEditPatch extends PostingEditPatch {
  const DebtReliefEditPatch({this.amount, this.liabilityAccountId});
  final Money? amount;
  final String? liabilityAccountId;
  @override
  BusinessPurpose get targetPurpose => BusinessPurpose.debtRelief;
  @override
  DebtReliefInstruction applyTo(PostingInstruction current) {
    if (current is! DebtReliefInstruction) {
      return LedgerViolationReason.unsupportedEditSource.throwException();
    }
    return DebtReliefInstruction(
      amount: amount ?? current.amount,
      liabilityAccountId: liabilityAccountId ?? current.liabilityAccountId,
      occurredAt: current.occurredAt,
      postedAt: current.postedAt,
      counterpartyId: current.counterpartyId,
      note: current.note,
      isExcludedFromStats: current.isExcludedFromStats,
      sourceKind: current.sourceKind,
    );
  }
}

class RefundEditPatch {
  const RefundEditPatch({
    this.amount,
    this.categoryAllocations,
    this.selfBorneAllocations,
    this.settlementAllocations,
  });

  final Money? amount;
  final List<AccountAmountAllocation>? categoryAllocations;
  final List<AccountAmountAllocation>? selfBorneAllocations;
  final List<AccountAmountAllocation>? settlementAllocations;

  RefundInstruction applyTo(RefundInstruction current) {
    final nextAmount = amount ?? current.amount;
    return RefundInstruction(
      parentTransactionId: current.parentTransactionId,
      amount: nextAmount,
      categoryAllocations: patchAllocations(
        current: current.categoryAllocations,
        total: nextAmount,
        explicit: categoryAllocations,
      ),
      selfBorneAllocations:
          selfBorneAllocations ?? current.selfBorneAllocations,
      settlementAllocations: patchAllocations(
        current: current.settlementAllocations,
        total: nextAmount,
        explicit: settlementAllocations,
      ),
      occurredAt: current.occurredAt,
      postedAt: current.postedAt,
      counterpartyId: current.counterpartyId,
      note: current.note,
    );
  }
}

T _applyPatch<T>(Patch<T>? patch, T current) {
  return switch (patch) {
    null => current,
    PatchSet<T>(:final value) => value,
    PatchClear<T>() => null as T,
  };
}
