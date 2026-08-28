import 'package:smartflow/core/money/money.dart';
import '../../entity/transaction.dart';
import '../../valobj/account_amount_allocation.dart';
import '../../valobj/ledger_enum.dart';
import '../../valobj/ledger_violation_reason.dart';
import '../../valobj/posting_instruction.dart';

/// `Instruction → 分项` 的逆。分项是过账输入的持久化形态,因此这里是纯查表:
/// 不读分录,也不依赖分录顺序。
abstract interface class PostingInstructionResolver {
  PostingInstruction resolve(Transaction transaction);

  RefundInstruction resolveRefund(Transaction transaction);
}

class DefaultPostingInstructionResolver implements PostingInstructionResolver {
  const DefaultPostingInstructionResolver();

  @override
  PostingInstruction resolve(Transaction transaction) {
    return switch (transaction.businessPurpose) {
      BusinessPurpose.dailyExpense => _resolveExpense(transaction),
      BusinessPurpose.dailyIncome => _resolveIncome(transaction),
      BusinessPurpose.reimbursementAdvance => _resolveReimbursementAdvance(
        transaction,
      ),
      BusinessPurpose.transfer => _resolveTransfer(transaction),
      BusinessPurpose.debtRepayment => _resolveRepayment(transaction),
      BusinessPurpose.borrowing => _resolveBorrowing(transaction),
      BusinessPurpose.lending => _resolveLending(transaction),
      BusinessPurpose.receivableCollection => _resolveCollection(transaction),
      BusinessPurpose.badDebt => _resolveBadDebt(transaction),
      BusinessPurpose.debtRelief => _resolveDebtRelief(transaction),
      _ =>
        LedgerViolationReason.unsupportedPostingInstructionResolution
            .throwException(
              message:
                  'Cannot resolve ${transaction.businessPurpose.name} as a '
                  'posting instruction.',
            ),
    };
  }

  @override
  RefundInstruction resolveRefund(Transaction transaction) {
    if (transaction.businessPurpose != BusinessPurpose.refund ||
        transaction.parentTransactionId == null) {
      return LedgerViolationReason.refundTransactionRequired.throwException(
        message: 'A refund transaction is required.',
      );
    }
    final settlements = _allocationsOf(
      transaction,
      TransactionRole.settlementIn,
    );
    final refundOffsets = _allocationsOf(
      transaction,
      TransactionRole.refundOffset,
    );
    final reimbursementCategories = _allocationsOf(
      transaction,
      TransactionRole.reimbursementExpenseCategory,
    );
    // Reimbursement refunds have two independent facts: category allocations
    // and the parent receivable account stored in refundOffset. The latter
    // must never be interpreted as a refunded category.
    final categories = reimbursementCategories.isNotEmpty
        ? reimbursementCategories
        : refundOffsets;
    if (settlements.isEmpty || categories.isEmpty) {
      return LedgerViolationReason.refundToAccountNotFound.throwException(
        message: 'Refund allocations cannot be resolved.',
      );
    }
    return RefundInstruction(
      parentTransactionId: transaction.parentTransactionId!,
      amount: transaction.primaryAmount,
      categoryAllocations: categories,
      settlementAllocations: settlements,
      occurredAt: transaction.occurredAt,
      postedAt: transaction.postedAt,
      counterpartyName: transaction.counterpartyName,
      note: transaction.note,
    );
  }

  ExpenseInstruction _resolveExpense(Transaction transaction) {
    final categories = _allocationsOf(transaction, TransactionRole.category);
    final settlements = _allocationsOf(
      transaction,
      TransactionRole.settlementOut,
    );
    if (categories.isEmpty || settlements.isEmpty) {
      return LedgerViolationReason.expenseInstructionUnresolvable
          .throwException(message: 'Expense accounts cannot be resolved.');
    }
    return ExpenseInstruction(
      amount: transaction.primaryAmount,
      categoryAllocations: categories,
      settlementAllocations: settlements,
      occurredAt: transaction.occurredAt,
      postedAt: transaction.postedAt,
      counterpartyName: transaction.counterpartyName,
      note: transaction.note,
      isExcludedFromStats: transaction.isExcludedFromStats,
      isExcludedFromBudget: transaction.isExcludedFromBudget,
      sourceKind: transaction.sourceKind,
      ownership: transaction.ownership,
    );
  }

  IncomeInstruction _resolveIncome(Transaction transaction) {
    final incomeAccountId = transaction.accountOf(TransactionRole.category);
    final receiveAccountId = transaction.accountOf(
      TransactionRole.settlementIn,
    );
    if (receiveAccountId == null || incomeAccountId == null) {
      return LedgerViolationReason.incomeInstructionUnresolvable.throwException(
        message: 'Income accounts cannot be resolved.',
      );
    }
    return IncomeInstruction(
      amount: transaction.primaryAmount,
      receiveAccountId: receiveAccountId,
      incomeAccountId: incomeAccountId,
      occurredAt: transaction.occurredAt,
      postedAt: transaction.postedAt,
      counterpartyName: transaction.counterpartyName,
      note: transaction.note,
      isExcludedFromStats: transaction.isExcludedFromStats,
      isExcludedFromBudget: transaction.isExcludedFromBudget,
      sourceKind: transaction.sourceKind,
      ownership: transaction.ownership,
    );
  }

  ReimbursementAdvanceInstruction _resolveReimbursementAdvance(
    Transaction transaction,
  ) {
    final categories = _allocationsOf(
      transaction,
      TransactionRole.reimbursementExpenseCategory,
    );
    final receivableAccountId = transaction.accountOf(
      TransactionRole.receivable,
    );
    final settlements = _allocationsOf(
      transaction,
      TransactionRole.settlementOut,
    );
    if (categories.isEmpty ||
        receivableAccountId == null ||
        settlements.isEmpty) {
      return LedgerViolationReason.reimbursementInstructionUnresolvable
          .throwException(
            message: 'Reimbursement advance accounts cannot be resolved.',
          );
    }
    return ReimbursementAdvanceInstruction(
      amount: transaction.primaryAmount,
      receivableAccountId: receivableAccountId,
      categoryAllocations: categories,
      settlementAllocations: settlements,
      occurredAt: transaction.occurredAt,
      postedAt: transaction.postedAt,
      counterpartyName: transaction.counterpartyName,
      note: transaction.note,
      isExcludedFromStats: transaction.isExcludedFromStats,
      isExcludedFromBudget: transaction.isExcludedFromBudget,
      sourceKind: transaction.sourceKind,
      ownership: transaction.ownership,
    );
  }

  TransferInstruction _resolveTransfer(Transaction transaction) {
    final fromAccountId = transaction.accountOf(TransactionRole.settlementOut);
    final toAccountId = transaction.accountOf(TransactionRole.settlementIn);
    if (fromAccountId == null || toAccountId == null) {
      return LedgerViolationReason.transferInstructionUnresolvable
          .throwException(message: 'Transfer accounts cannot be resolved.');
    }
    return TransferInstruction(
      amount: transaction.primaryAmount,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      feeAmount: transaction.amountOf(TransactionRole.fee),
      occurredAt: transaction.occurredAt,
      postedAt: transaction.postedAt,
      counterpartyName: transaction.counterpartyName,
      note: transaction.note,
      sourceKind: transaction.sourceKind,
    );
  }

  BorrowingInstruction _resolveBorrowing(Transaction transaction) {
    final liabilityAccountId = transaction.accountOf(TransactionRole.liability);
    final receiveAccountId = transaction.accountOf(
      TransactionRole.settlementIn,
    );
    if (receiveAccountId == null || liabilityAccountId == null) {
      return LedgerViolationReason.borrowingInstructionUnresolvable
          .throwException(message: 'Borrowing accounts cannot be resolved.');
    }
    return BorrowingInstruction(
      amount: transaction.primaryAmount,
      liabilityAccountId: liabilityAccountId,
      receiveAccountId: receiveAccountId,
      occurredAt: transaction.occurredAt,
      postedAt: transaction.postedAt,
      counterpartyName: transaction.counterpartyName,
      note: transaction.note,
      ownership: transaction.ownership,
      sourceKind: transaction.sourceKind,
    );
  }

  RepaymentInstruction _resolveRepayment(Transaction transaction) {
    final principal = transaction.amountOf(TransactionRole.liability);
    final liabilityAccountId = transaction.accountOf(TransactionRole.liability);
    final paidFromAccountId = transaction.accountOf(
      TransactionRole.settlementOut,
    );
    if (principal == null ||
        liabilityAccountId == null ||
        paidFromAccountId == null) {
      return LedgerViolationReason.repaymentInstructionUnresolvable
          .throwException(message: 'Repayment accounts cannot be resolved.');
    }
    return RepaymentInstruction(
      principal: principal,
      interest: transaction.amountOf(TransactionRole.interest),
      fee: transaction.amountOf(TransactionRole.fee),
      discount: transaction.amountOf(TransactionRole.discount),
      liabilityAccountId: liabilityAccountId,
      paidFromAccountId: paidFromAccountId,
      occurredAt: transaction.occurredAt,
      postedAt: transaction.postedAt,
      counterpartyName: transaction.counterpartyName,
      note: transaction.note,
      ownership: transaction.ownership,
      sourceKind: transaction.sourceKind,
    );
  }

  LendingInstruction _resolveLending(Transaction transaction) {
    final receivableAccountId = transaction.accountOf(
      TransactionRole.receivable,
    );
    final paidFromAccountId = transaction.accountOf(
      TransactionRole.settlementOut,
    );
    if (receivableAccountId == null || paidFromAccountId == null) {
      return LedgerViolationReason.lendingInstructionUnresolvable
          .throwException(message: 'Lending accounts cannot be resolved.');
    }
    return LendingInstruction(
      amount: transaction.primaryAmount,
      receivableAccountId: receivableAccountId,
      paidFromAccountId: paidFromAccountId,
      occurredAt: transaction.occurredAt,
      postedAt: transaction.postedAt,
      counterpartyName: transaction.counterpartyName,
      note: transaction.note,
      sourceKind: transaction.sourceKind,
    );
  }

  ReceivableCollectionInstruction _resolveCollection(Transaction transaction) {
    final principal = transaction.amountOf(TransactionRole.receivable);
    final receivableAccountId = transaction.accountOf(
      TransactionRole.receivable,
    );
    final receiveAccountId = transaction.accountOf(
      TransactionRole.settlementIn,
    );
    if (principal == null ||
        receivableAccountId == null ||
        receiveAccountId == null) {
      return LedgerViolationReason.receivableCollectionInstructionUnresolvable
          .throwException(
            message: 'Receivable collection accounts cannot be resolved.',
          );
    }
    return ReceivableCollectionInstruction(
      principal: principal,
      interest: transaction.amountOf(TransactionRole.interest) ?? Money.zero(),
      receivableAccountId: receivableAccountId,
      receiveAccountId: receiveAccountId,
      occurredAt: transaction.occurredAt,
      postedAt: transaction.postedAt,
      counterpartyName: transaction.counterpartyName,
      note: transaction.note,
      sourceKind: transaction.sourceKind,
    );
  }

  BadDebtInstruction _resolveBadDebt(Transaction transaction) {
    final receivableAccountId = transaction.accountOf(
      TransactionRole.receivable,
    );
    if (receivableAccountId == null) {
      return LedgerViolationReason.badDebtInstructionUnresolvable
          .throwException(message: 'Bad debt accounts cannot be resolved.');
    }
    return BadDebtInstruction(
      amount: transaction.primaryAmount,
      receivableAccountId: receivableAccountId,
      occurredAt: transaction.occurredAt,
      postedAt: transaction.postedAt,
      counterpartyName: transaction.counterpartyName,
      note: transaction.note,
      isExcludedFromStats: transaction.isExcludedFromStats,
      isExcludedFromBudget: transaction.isExcludedFromBudget,
      sourceKind: transaction.sourceKind,
    );
  }

  DebtReliefInstruction _resolveDebtRelief(Transaction transaction) {
    final liabilityAccountId = transaction.accountOf(TransactionRole.liability);
    if (liabilityAccountId == null) {
      return LedgerViolationReason.debtReliefInstructionUnresolvable
          .throwException(message: 'Debt relief accounts cannot be resolved.');
    }
    return DebtReliefInstruction(
      amount: transaction.primaryAmount,
      liabilityAccountId: liabilityAccountId,
      occurredAt: transaction.occurredAt,
      postedAt: transaction.postedAt,
      counterpartyName: transaction.counterpartyName,
      note: transaction.note,
      isExcludedFromStats: transaction.isExcludedFromStats,
      sourceKind: transaction.sourceKind,
    );
  }
}

List<AccountAmountAllocation> _allocationsOf(
  Transaction transaction,
  TransactionRole role,
) {
  return [
    for (final line in transaction.linesOf(role))
      AccountAmountAllocation(accountId: line.accountId!, amount: line.amount),
  ];
}
