import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../../../core/result/result.dart';
import 'ledger_enum.dart';
import 'transaction_ownership.dart';

sealed class PostingInstruction {
  const PostingInstruction();

  BusinessPurpose get businessPurpose;

  Set<String> get accountIds;
}

class ExpenseInstruction extends PostingInstruction {
  const ExpenseInstruction({
    required this.amount,
    required this.paidFromAccountId,
    required this.expenseAccountId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
    this.sourceKind = SourceKind.manual,
    this.ownership,
  });

  final Money amount;
  final String paidFromAccountId;
  final String expenseAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
  final SourceKind sourceKind;
  final TransactionOwnership? ownership;

  @override
  BusinessPurpose get businessPurpose => BusinessPurpose.dailyExpense;

  @override
  Set<String> get accountIds => {paidFromAccountId, expenseAccountId};

  ExpenseInstruction copyWith({
    Money? amount,
    String? paidFromAccountId,
    String? expenseAccountId,
    DateTime? occurredAt,
    String? counterpartyName,
    String? note,
    bool? isExcludedFromStats,
    bool? isExcludedFromBudget,
    SourceKind? sourceKind,
    TransactionOwnership? ownership,
  }) {
    return ExpenseInstruction(
      amount: amount ?? this.amount,
      paidFromAccountId: paidFromAccountId ?? this.paidFromAccountId,
      expenseAccountId: expenseAccountId ?? this.expenseAccountId,
      occurredAt: occurredAt ?? this.occurredAt,
      counterpartyName: counterpartyName ?? this.counterpartyName,
      note: note ?? this.note,
      isExcludedFromStats: isExcludedFromStats ?? this.isExcludedFromStats,
      isExcludedFromBudget: isExcludedFromBudget ?? this.isExcludedFromBudget,
      sourceKind: sourceKind ?? this.sourceKind,
      ownership: ownership ?? this.ownership,
    );
  }
}

class IncomeInstruction extends PostingInstruction {
  const IncomeInstruction({
    required this.amount,
    required this.receiveAccountId,
    required this.incomeAccountId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats = false,
    this.sourceKind = SourceKind.manual,
    this.ownership,
  });

  final Money amount;
  final String receiveAccountId;
  final String incomeAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final SourceKind sourceKind;
  final TransactionOwnership? ownership;

  @override
  BusinessPurpose get businessPurpose => BusinessPurpose.dailyIncome;

  @override
  Set<String> get accountIds => {receiveAccountId, incomeAccountId};

  IncomeInstruction copyWith({
    Money? amount,
    String? receiveAccountId,
    String? incomeAccountId,
    DateTime? occurredAt,
    String? counterpartyName,
    String? note,
    bool? isExcludedFromStats,
    SourceKind? sourceKind,
    TransactionOwnership? ownership,
  }) {
    return IncomeInstruction(
      amount: amount ?? this.amount,
      receiveAccountId: receiveAccountId ?? this.receiveAccountId,
      incomeAccountId: incomeAccountId ?? this.incomeAccountId,
      occurredAt: occurredAt ?? this.occurredAt,
      counterpartyName: counterpartyName ?? this.counterpartyName,
      note: note ?? this.note,
      isExcludedFromStats: isExcludedFromStats ?? this.isExcludedFromStats,
      sourceKind: sourceKind ?? this.sourceKind,
      ownership: ownership ?? this.ownership,
    );
  }
}

class ReimbursementAdvanceInstruction extends PostingInstruction {
  const ReimbursementAdvanceInstruction({
    required this.amount,
    required this.receivableAccountId,
    required this.paidFromAccountId,
    required this.expenseAccountId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
    this.sourceKind = SourceKind.manual,
    this.ownership,
  });

  final Money amount;
  final String receivableAccountId;
  final String paidFromAccountId;
  final String expenseAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final SourceKind sourceKind;
  final TransactionOwnership? ownership;

  @override
  BusinessPurpose get businessPurpose => BusinessPurpose.reimbursementAdvance;

  @override
  Set<String> get accountIds => {
    receivableAccountId,
    paidFromAccountId,
    expenseAccountId,
  };

  ReimbursementAdvanceInstruction copyWith({
    Money? amount,
    String? receivableAccountId,
    String? paidFromAccountId,
    String? expenseAccountId,
    DateTime? occurredAt,
    String? counterpartyName,
    String? note,
    SourceKind? sourceKind,
    TransactionOwnership? ownership,
  }) {
    return ReimbursementAdvanceInstruction(
      amount: amount ?? this.amount,
      receivableAccountId: receivableAccountId ?? this.receivableAccountId,
      paidFromAccountId: paidFromAccountId ?? this.paidFromAccountId,
      expenseAccountId: expenseAccountId ?? this.expenseAccountId,
      occurredAt: occurredAt ?? this.occurredAt,
      counterpartyName: counterpartyName ?? this.counterpartyName,
      note: note ?? this.note,
      sourceKind: sourceKind ?? this.sourceKind,
      ownership: ownership ?? this.ownership,
    );
  }
}

class RefundInstruction {
  const RefundInstruction({
    required this.parentTransactionId,
    required this.amount,
    required this.refundToAccountId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
  });

  final String parentTransactionId;
  final Money amount;
  final String refundToAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
}

class ReimbursementCloseInstruction {
  const ReimbursementCloseInstruction({
    required this.advanceTransactionId,
    required this.actualReceivedAmount,
    required this.receivableAccountId,
    required this.receiveAccountId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
  });

  final String advanceTransactionId;
  final Money actualReceivedAmount;
  final String receivableAccountId;
  final String receiveAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
}

class TransferInstruction extends PostingInstruction {
  const TransferInstruction({
    required this.amount,
    required this.fromAccountId,
    required this.toAccountId,
    required this.occurredAt,
    this.feeAmount,
    this.counterpartyName,
    this.note,
    this.sourceKind = SourceKind.manual,
  });

  final Money amount;
  final String fromAccountId;
  final String toAccountId;
  final Money? feeAmount;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
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
    String? counterpartyName,
    String? note,
    SourceKind? sourceKind,
  }) {
    return TransferInstruction(
      amount: amount ?? this.amount,
      fromAccountId: fromAccountId ?? this.fromAccountId,
      toAccountId: toAccountId ?? this.toAccountId,
      feeAmount: feeAmount ?? this.feeAmount,
      occurredAt: occurredAt ?? this.occurredAt,
      counterpartyName: counterpartyName ?? this.counterpartyName,
      note: note ?? this.note,
      sourceKind: sourceKind ?? this.sourceKind,
    );
  }
}

class ReimbursementReceiptInstruction {
  const ReimbursementReceiptInstruction({
    required this.advanceTransactionId,
    required this.amount,
    required this.receivableAccountId,
    required this.receiveAccountId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
  });

  final String advanceTransactionId;
  final Money amount;
  final String receivableAccountId;
  final String receiveAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
}

class RepaymentInstruction extends PostingInstruction {
  const RepaymentInstruction({
    required this.principal,
    required this.liabilityAccountId,
    required this.paidFromAccountId,
    required this.occurredAt,
    this.interest,
    this.fee,
    this.discount,
    this.counterpartyName,
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
  final String? counterpartyName;
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
    String? counterpartyName,
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
      counterpartyName: counterpartyName ?? this.counterpartyName,
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
    this.counterpartyName,
    this.note,
    this.ownership,
    this.sourceKind = SourceKind.manual,
  });

  final Money amount;
  final String liabilityAccountId;
  final String receiveAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
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
    String? counterpartyName,
    String? note,
    TransactionOwnership? ownership,
    SourceKind? sourceKind,
  }) {
    return BorrowingInstruction(
      amount: amount ?? this.amount,
      liabilityAccountId: liabilityAccountId ?? this.liabilityAccountId,
      receiveAccountId: receiveAccountId ?? this.receiveAccountId,
      occurredAt: occurredAt ?? this.occurredAt,
      counterpartyName: counterpartyName ?? this.counterpartyName,
      note: note ?? this.note,
      ownership: ownership ?? this.ownership,
      sourceKind: sourceKind ?? this.sourceKind,
    );
  }
}

class OpeningBalanceInstruction {
  const OpeningBalanceInstruction({
    required this.accountId,
    required this.amount,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
  });

  final String accountId;
  final Money amount;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
}

class BalanceAdjustmentInstruction {
  const BalanceAdjustmentInstruction({
    required this.accountId,
    required this.targetBalance,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
  });

  final String accountId;
  final Money targetBalance;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
}

class ReplaceParentTransactionInstruction {
  const ReplaceParentTransactionInstruction({
    required this.transactionId,
    required this.expectedCurrentPurpose,
    required this.replacementPatch,
    this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats,
    this.isExcludedFromBudget,
  });

  final String transactionId;
  final BusinessPurpose expectedCurrentPurpose;
  final PostingReplacementPatch replacementPatch;
  final DateTime? occurredAt;
  final Patch<String?>? counterpartyName;
  final Patch<String?>? note;
  final bool? isExcludedFromStats;
  final bool? isExcludedFromBudget;
}

class ReplaceRefundTransactionInstruction {
  const ReplaceRefundTransactionInstruction({
    required this.transactionId,
    required this.replacementPatch,
    this.occurredAt,
    this.counterpartyName,
    this.note,
  });

  final String transactionId;
  final RefundReplacementPatch replacementPatch;
  final DateTime? occurredAt;
  final Patch<String?>? counterpartyName;
  final Patch<String?>? note;
}

class ReplaceReimbursementReceiptTransactionInstruction {
  const ReplaceReimbursementReceiptTransactionInstruction({
    required this.transactionId,
    this.amount,
    this.receivableAccountId,
    this.receiveAccountId,
    this.occurredAt,
    this.counterpartyName,
    this.note,
  });

  final String transactionId;
  final Money? amount;
  final String? receivableAccountId;
  final String? receiveAccountId;
  final DateTime? occurredAt;
  final Patch<String?>? counterpartyName;
  final Patch<String?>? note;
}

class ReplaceReimbursementCloseTransactionInstruction {
  const ReplaceReimbursementCloseTransactionInstruction({
    required this.transactionId,
    this.actualReceivedAmount,
    this.receivableAccountId,
    this.receiveAccountId,
    this.occurredAt,
    this.counterpartyName,
    this.note,
  });

  final String transactionId;
  final Money? actualReceivedAmount;
  final String? receivableAccountId;
  final String? receiveAccountId;
  final DateTime? occurredAt;
  final Patch<String?>? counterpartyName;
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
    this.counterpartyName,
    this.note,
  });

  final String transactionId;
  final DateTime? occurredAt;
  final Patch<String?>? counterpartyName;
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

sealed class PostingReplacementPatch {
  const PostingReplacementPatch();

  BusinessPurpose get targetPurpose;

  Result<PostingInstruction> applyTo(PostingInstruction current);
}

class ExpenseReplacementPatch extends PostingReplacementPatch {
  const ExpenseReplacementPatch({
    this.amount,
    this.paidFromAccountId,
    this.expenseAccountId,
  });

  final Money? amount;
  final String? paidFromAccountId;
  final String? expenseAccountId;

  @override
  BusinessPurpose get targetPurpose => BusinessPurpose.dailyExpense;

  @override
  Result<ExpenseInstruction> applyTo(PostingInstruction current) {
    if (current is ExpenseInstruction) {
      return Result.success(
        current.copyWith(
          amount: amount,
          paidFromAccountId: paidFromAccountId,
          expenseAccountId: expenseAccountId,
        ),
      );
    }
    if (current is ReimbursementAdvanceInstruction) {
      return Result.success(
        ExpenseInstruction(
          amount: amount ?? current.amount,
          paidFromAccountId: paidFromAccountId ?? current.paidFromAccountId,
          expenseAccountId: expenseAccountId ?? current.expenseAccountId,
          occurredAt: current.occurredAt,
          counterpartyName: current.counterpartyName,
          note: current.note,
          sourceKind: current.sourceKind,
          ownership: current.ownership,
        ),
      );
    }
    return const Result.failure(
      Failure(
        code: 'unsupported_replacement_source',
        message: 'This transaction cannot be replaced as an expense.',
      ),
    );
  }
}

class IncomeReplacementPatch extends PostingReplacementPatch {
  const IncomeReplacementPatch({
    this.amount,
    this.receiveAccountId,
    this.incomeAccountId,
  });

  final Money? amount;
  final String? receiveAccountId;
  final String? incomeAccountId;

  @override
  BusinessPurpose get targetPurpose => BusinessPurpose.dailyIncome;

  @override
  Result<IncomeInstruction> applyTo(PostingInstruction current) {
    if (current is IncomeInstruction) {
      return Result.success(
        current.copyWith(
          amount: amount,
          receiveAccountId: receiveAccountId,
          incomeAccountId: incomeAccountId,
        ),
      );
    }
    return const Result.failure(
      Failure(
        code: 'unsupported_replacement_source',
        message: 'This transaction cannot be replaced as an income.',
      ),
    );
  }
}

class TransferReplacementPatch extends PostingReplacementPatch {
  const TransferReplacementPatch({
    this.amount,
    this.fromAccountId,
    this.toAccountId,
    this.feeAmount,
  });

  final Money? amount;
  final String? fromAccountId;
  final String? toAccountId;
  final Money? feeAmount;

  @override
  BusinessPurpose get targetPurpose => BusinessPurpose.transfer;

  @override
  Result<TransferInstruction> applyTo(PostingInstruction current) {
    if (current is TransferInstruction) {
      return Result.success(
        TransferInstruction(
          amount: amount ?? current.amount,
          fromAccountId: fromAccountId ?? current.fromAccountId,
          toAccountId: toAccountId ?? current.toAccountId,
          feeAmount: feeAmount ?? current.feeAmount,
          occurredAt: current.occurredAt,
          counterpartyName: current.counterpartyName,
          note: current.note,
          sourceKind: current.sourceKind,
        ),
      );
    }
    return const Result.failure(
      Failure(
        code: 'unsupported_replacement_source',
        message: 'This transaction cannot be replaced as a transfer.',
      ),
    );
  }
}

class ReimbursementAdvanceReplacementPatch extends PostingReplacementPatch {
  const ReimbursementAdvanceReplacementPatch({
    this.amount,
    this.receivableAccountId,
    this.paidFromAccountId,
    this.expenseAccountId,
  });

  final Money? amount;
  final String? receivableAccountId;
  final String? paidFromAccountId;
  final String? expenseAccountId;

  @override
  BusinessPurpose get targetPurpose => BusinessPurpose.reimbursementAdvance;

  @override
  Result<ReimbursementAdvanceInstruction> applyTo(PostingInstruction current) {
    if (current is ReimbursementAdvanceInstruction) {
      return Result.success(
        current.copyWith(
          amount: amount,
          receivableAccountId: receivableAccountId,
          paidFromAccountId: paidFromAccountId,
          expenseAccountId: expenseAccountId,
        ),
      );
    }
    return const Result.failure(
      Failure(
        code: 'unsupported_replacement_source',
        message:
            'This transaction cannot be replaced as a reimbursement advance.',
      ),
    );
  }
}

class BorrowingReplacementPatch extends PostingReplacementPatch {
  const BorrowingReplacementPatch({
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
  Result<BorrowingInstruction> applyTo(PostingInstruction current) {
    if (current is BorrowingInstruction) {
      return Result.success(
        current.copyWith(
          amount: amount,
          liabilityAccountId: liabilityAccountId,
          receiveAccountId: receiveAccountId,
        ),
      );
    }
    return const Result.failure(
      Failure(
        code: 'unsupported_replacement_source',
        message: 'This transaction cannot be replaced as borrowing.',
      ),
    );
  }
}

class RepaymentReplacementPatch extends PostingReplacementPatch {
  const RepaymentReplacementPatch({
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
  Result<RepaymentInstruction> applyTo(PostingInstruction current) {
    if (current is RepaymentInstruction) {
      return Result.success(
        RepaymentInstruction(
          principal: principal ?? current.principal,
          interest: _applyPatch(interest, current.interest),
          fee: _applyPatch(fee, current.fee),
          discount: _applyPatch(discount, current.discount),
          liabilityAccountId: liabilityAccountId ?? current.liabilityAccountId,
          paidFromAccountId: paidFromAccountId ?? current.paidFromAccountId,
          occurredAt: current.occurredAt,
          counterpartyName: current.counterpartyName,
          note: current.note,
          ownership: current.ownership,
          sourceKind: current.sourceKind,
        ),
      );
    }
    return const Result.failure(
      Failure(
        code: 'unsupported_replacement_source',
        message: 'This transaction cannot be replaced as repayment.',
      ),
    );
  }
}

class RefundReplacementPatch {
  const RefundReplacementPatch({this.amount, this.refundToAccountId});

  final Money? amount;
  final String? refundToAccountId;

  Result<RefundInstruction> applyTo(RefundInstruction current) {
    return Result.success(
      RefundInstruction(
        parentTransactionId: current.parentTransactionId,
        amount: amount ?? current.amount,
        refundToAccountId: refundToAccountId ?? current.refundToAccountId,
        occurredAt: current.occurredAt,
        counterpartyName: current.counterpartyName,
        note: current.note,
      ),
    );
  }
}

String? resolveRefundOffsetAccountId(PostingInstruction parentInstruction) {
  return switch (parentInstruction) {
    ExpenseInstruction(:final expenseAccountId) => expenseAccountId,
    ReimbursementAdvanceInstruction(:final receivableAccountId) =>
      receivableAccountId,
    _ => null,
  };
}

T _applyPatch<T>(Patch<T>? patch, T current) {
  return switch (patch) {
    null => current,
    PatchSet<T>(:final value) => value,
    PatchClear<T>() => null as T,
  };
}
