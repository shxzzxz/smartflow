import 'package:smartflow/core/error/failure.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/result/result.dart';
import '../../entity/transaction.dart';
import '../../valobj/ledger_enum.dart';
import '../../valobj/posting_instruction.dart';

abstract interface class PostingInstructionResolver {
  Result<PostingInstruction> resolve(Transaction transaction);

  Result<RefundInstruction> resolveRefund(Transaction transaction);
}

class DefaultPostingInstructionResolver implements PostingInstructionResolver {
  const DefaultPostingInstructionResolver();

  @override
  Result<PostingInstruction> resolve(Transaction transaction) {
    return switch (transaction.businessPurpose) {
      BusinessPurpose.dailyExpense => _resolveExpense(transaction),
      BusinessPurpose.dailyIncome => _resolveIncome(transaction),
      BusinessPurpose.reimbursementAdvance => _resolveReimbursementAdvance(
        transaction,
      ),
      BusinessPurpose.transfer => _resolveTransfer(transaction),
      BusinessPurpose.debtRepayment => _resolveRepayment(transaction),
      BusinessPurpose.borrowing => _resolveBorrowing(transaction),
      _ => Result.failure(
        Failure(
          code: 'unsupported_posting_instruction_resolution',
          message:
              'Cannot resolve ${transaction.businessPurpose.name} as a '
              'posting instruction.',
        ),
      ),
    };
  }

  @override
  Result<RefundInstruction> resolveRefund(Transaction transaction) {
    if (transaction.businessPurpose != BusinessPurpose.refund ||
        transaction.parentTransactionId == null) {
      return const Result.failure(
        Failure(
          code: 'refund_transaction_required',
          message: 'A refund transaction is required.',
        ),
      );
    }
    final refundTo = _firstEntryAccount(
      transaction,
      direction: EntryDirection.debit,
    );
    if (refundTo == null) {
      return const Result.failure(
        Failure(
          code: 'refund_to_account_not_found',
          message: 'Refund receiving account cannot be resolved.',
        ),
      );
    }
    return Result.success(
      RefundInstruction(
        parentTransactionId: transaction.parentTransactionId!,
        amount: transaction.primaryAmount,
        refundToAccountId: refundTo,
        occurredAt: transaction.occurredAt,
        counterpartyName: transaction.counterpartyName,
        note: transaction.note,
      ),
    );
  }

  Result<ExpenseInstruction> _resolveExpense(Transaction transaction) {
    final expenseAccountId = _firstEntryAccount(
      transaction,
      direction: EntryDirection.debit,
    );
    final paidFromAccountId = _firstEntryAccount(
      transaction,
      direction: EntryDirection.credit,
    );
    if (expenseAccountId == null || paidFromAccountId == null) {
      return const Result.failure(
        Failure(
          code: 'expense_instruction_unresolvable',
          message: 'Expense accounts cannot be resolved.',
        ),
      );
    }
    return Result.success(
      ExpenseInstruction(
        amount: transaction.primaryAmount,
        paidFromAccountId: paidFromAccountId,
        expenseAccountId: expenseAccountId,
        occurredAt: transaction.occurredAt,
        counterpartyName: transaction.counterpartyName,
        note: transaction.note,
        isExcludedFromStats: transaction.isExcludedFromStats,
        isExcludedFromBudget: transaction.isExcludedFromBudget,
        sourceKind: transaction.sourceKind,
        ownership: transaction.ownership,
      ),
    );
  }

  Result<IncomeInstruction> _resolveIncome(Transaction transaction) {
    final receiveAccountId = _firstEntryAccount(
      transaction,
      direction: EntryDirection.debit,
    );
    final incomeAccountId = _firstEntryAccount(
      transaction,
      direction: EntryDirection.credit,
    );
    if (receiveAccountId == null || incomeAccountId == null) {
      return const Result.failure(
        Failure(
          code: 'income_instruction_unresolvable',
          message: 'Income accounts cannot be resolved.',
        ),
      );
    }
    return Result.success(
      IncomeInstruction(
        amount: transaction.primaryAmount,
        receiveAccountId: receiveAccountId,
        incomeAccountId: incomeAccountId,
        occurredAt: transaction.occurredAt,
        counterpartyName: transaction.counterpartyName,
        note: transaction.note,
        isExcludedFromStats: transaction.isExcludedFromStats,
        sourceKind: transaction.sourceKind,
        ownership: transaction.ownership,
      ),
    );
  }

  Result<ReimbursementAdvanceInstruction> _resolveReimbursementAdvance(
    Transaction transaction,
  ) {
    final expenseAccountId = transaction.reimbursementExpenseAccountId;
    final receivableAccountId = _firstEntryAccount(
      transaction,
      direction: EntryDirection.debit,
      excludeAccountId: expenseAccountId,
    );
    final paidFromAccountId = _firstEntryAccount(
      transaction,
      direction: EntryDirection.credit,
      excludeAccountId: expenseAccountId,
    );
    if (expenseAccountId == null ||
        receivableAccountId == null ||
        paidFromAccountId == null) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_instruction_unresolvable',
          message: 'Reimbursement advance accounts cannot be resolved.',
        ),
      );
    }
    return Result.success(
      ReimbursementAdvanceInstruction(
        amount: transaction.primaryAmount,
        receivableAccountId: receivableAccountId,
        paidFromAccountId: paidFromAccountId,
        expenseAccountId: expenseAccountId,
        occurredAt: transaction.occurredAt,
        counterpartyName: transaction.counterpartyName,
        note: transaction.note,
        sourceKind: transaction.sourceKind,
        ownership: transaction.ownership,
      ),
    );
  }

  Result<TransferInstruction> _resolveTransfer(Transaction transaction) {
    final fromAccountId = _firstEntryAccount(
      transaction,
      direction: EntryDirection.credit,
    );
    final toAccountId = _entryForDetailAmount(
      transaction,
      detailType: TransactionDetailType.transferMain,
      direction: EntryDirection.debit,
    );
    final feeAmount = _detailAmount(
      transaction,
      TransactionDetailType.transferFee,
    );
    if (fromAccountId == null || toAccountId == null) {
      return const Result.failure(
        Failure(
          code: 'transfer_instruction_unresolvable',
          message: 'Transfer accounts cannot be resolved.',
        ),
      );
    }
    return Result.success(
      TransferInstruction(
        amount: transaction.primaryAmount,
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        feeAmount: feeAmount,
        occurredAt: transaction.occurredAt,
        counterpartyName: transaction.counterpartyName,
        note: transaction.note,
        sourceKind: transaction.sourceKind,
      ),
    );
  }

  Result<BorrowingInstruction> _resolveBorrowing(Transaction transaction) {
    final receiveAccountId = _firstEntryAccount(
      transaction,
      direction: EntryDirection.debit,
    );
    final liabilityAccountId = _firstEntryAccount(
      transaction,
      direction: EntryDirection.credit,
    );
    if (receiveAccountId == null || liabilityAccountId == null) {
      return const Result.failure(
        Failure(
          code: 'borrowing_instruction_unresolvable',
          message: 'Borrowing accounts cannot be resolved.',
        ),
      );
    }
    return Result.success(
      BorrowingInstruction(
        amount: transaction.primaryAmount,
        liabilityAccountId: liabilityAccountId,
        receiveAccountId: receiveAccountId,
        occurredAt: transaction.occurredAt,
        counterpartyName: transaction.counterpartyName,
        note: transaction.note,
        ownership: transaction.ownership,
        sourceKind: transaction.sourceKind,
      ),
    );
  }

  Result<RepaymentInstruction> _resolveRepayment(Transaction transaction) {
    final principal = _detailAmount(
      transaction,
      TransactionDetailType.repaymentPrincipal,
    );
    final liabilityAccountId = _entryForDetailAmount(
      transaction,
      detailType: TransactionDetailType.repaymentPrincipal,
      direction: EntryDirection.debit,
    );
    final paidFromAccountId = transaction.entries.last.accountId;
    if (principal == null || liabilityAccountId == null) {
      return const Result.failure(
        Failure(
          code: 'repayment_instruction_unresolvable',
          message: 'Repayment accounts cannot be resolved.',
        ),
      );
    }
    final interest = _detailAmount(
      transaction,
      TransactionDetailType.repaymentInterest,
    );
    final fee = _detailAmount(transaction, TransactionDetailType.repaymentFee);
    final discount = _detailAmount(
      transaction,
      TransactionDetailType.repaymentDiscount,
    );
    return Result.success(
      RepaymentInstruction(
        principal: principal,
        interest: interest,
        fee: fee,
        discount: discount,
        liabilityAccountId: liabilityAccountId,
        paidFromAccountId: paidFromAccountId,
        occurredAt: transaction.occurredAt,
        counterpartyName: transaction.counterpartyName,
        note: transaction.note,
        ownership: transaction.ownership,
        sourceKind: transaction.sourceKind,
      ),
    );
  }

  Money? _detailAmount(Transaction transaction, TransactionDetailType type) {
    for (final detail in transaction.details) {
      if (detail.type == type) return detail.amount;
    }
    return null;
  }

  String? _entryForDetailAmount(
    Transaction transaction, {
    required TransactionDetailType detailType,
    required EntryDirection direction,
  }) {
    final amount = _detailAmount(transaction, detailType);
    if (amount == null) return null;
    for (final entry in transaction.entries) {
      if (entry.direction == direction && entry.amount == amount) {
        return entry.accountId;
      }
    }
    return null;
  }

  String? _firstEntryAccount(
    Transaction transaction, {
    required EntryDirection direction,
    String? excludeAccountId,
  }) {
    for (final entry in transaction.entries) {
      if (entry.direction != direction) continue;
      if (entry.accountId == excludeAccountId) continue;
      return entry.accountId;
    }
    return null;
  }
}
