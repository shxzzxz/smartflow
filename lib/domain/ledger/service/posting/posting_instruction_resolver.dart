import 'package:smartflow/core/money/money.dart';
import '../../entity/account.dart';
import '../../entity/transaction.dart';
import '../../valobj/account_usage.dart';
import '../../valobj/ledger_enum.dart';
import '../../valobj/ledger_violation_reason.dart';
import '../../valobj/posting_instruction.dart';

abstract interface class PostingInstructionResolver {
  PostingInstruction resolve(
    Transaction transaction, {
    Map<String, Account> accountsById = const {},
  });

  RefundInstruction resolveRefund(Transaction transaction);
}

class DefaultPostingInstructionResolver implements PostingInstructionResolver {
  const DefaultPostingInstructionResolver();

  @override
  PostingInstruction resolve(
    Transaction transaction, {
    Map<String, Account> accountsById = const {},
  }) {
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
      BusinessPurpose.receivableCollection => _resolveCollection(
        transaction,
        accountsById,
      ),
      BusinessPurpose.badDebt => _resolveBadDebt(transaction),
      BusinessPurpose.debtRelief => _resolveDebtRelief(transaction),
      _ => LedgerViolationReason.unsupportedPostingInstructionResolution
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
    final refundTo = _firstEntryAccount(
      transaction,
      direction: EntryDirection.debit,
    );
    if (refundTo == null) {
      return LedgerViolationReason.refundToAccountNotFound.throwException(
        message: 'Refund receiving account cannot be resolved.',
      );
    }
    return RefundInstruction(
      parentTransactionId: transaction.parentTransactionId!,
      amount: transaction.primaryAmount,
      refundToAccountId: refundTo,
      occurredAt: transaction.occurredAt,
      postedAt: transaction.postedAt,
      counterpartyName: transaction.counterpartyName,
      note: transaction.note,
    );
  }

  ExpenseInstruction _resolveExpense(Transaction transaction) {
    final expenseAccountId = _firstEntryAccount(
      transaction,
      direction: EntryDirection.debit,
    );
    final paidFromAccountId = _firstEntryAccount(
      transaction,
      direction: EntryDirection.credit,
    );
    if (expenseAccountId == null || paidFromAccountId == null) {
      return LedgerViolationReason.expenseInstructionUnresolvable
          .throwException(message: 'Expense accounts cannot be resolved.');
    }
    return ExpenseInstruction(
      amount: transaction.primaryAmount,
      paidFromAccountId: paidFromAccountId,
      expenseAccountId: expenseAccountId,
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
    final receiveAccountId = _firstEntryAccount(
      transaction,
      direction: EntryDirection.debit,
    );
    final incomeAccountId = _firstEntryAccount(
      transaction,
      direction: EntryDirection.credit,
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
      return LedgerViolationReason.reimbursementInstructionUnresolvable
          .throwException(
            message: 'Reimbursement advance accounts cannot be resolved.',
          );
    }
    return ReimbursementAdvanceInstruction(
      amount: transaction.primaryAmount,
      receivableAccountId: receivableAccountId,
      paidFromAccountId: paidFromAccountId,
      expenseAccountId: expenseAccountId,
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
      return LedgerViolationReason.transferInstructionUnresolvable
          .throwException(message: 'Transfer accounts cannot be resolved.');
    }
    return TransferInstruction(
      amount: transaction.primaryAmount,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      feeAmount: feeAmount,
      occurredAt: transaction.occurredAt,
      postedAt: transaction.postedAt,
      counterpartyName: transaction.counterpartyName,
      note: transaction.note,
      sourceKind: transaction.sourceKind,
    );
  }

  BorrowingInstruction _resolveBorrowing(Transaction transaction) {
    final receiveAccountId = _firstEntryAccount(
      transaction,
      direction: EntryDirection.debit,
    );
    final liabilityAccountId = _firstEntryAccount(
      transaction,
      direction: EntryDirection.credit,
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
      return LedgerViolationReason.repaymentInstructionUnresolvable
          .throwException(message: 'Repayment accounts cannot be resolved.');
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
    return RepaymentInstruction(
      principal: principal,
      interest: interest,
      fee: fee,
      discount: discount,
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

  LendingInstruction _resolveLending(Transaction transaction) =>
      LendingInstruction(
        amount: transaction.primaryAmount,
        receivableAccountId:
            _entryForDetailAmount(
              transaction,
              detailType: TransactionDetailType.lendingPrincipal,
              direction: EntryDirection.debit,
            )!,
        paidFromAccountId:
            _entryForDetailAmount(
              transaction,
              detailType: TransactionDetailType.lendingPrincipal,
              direction: EntryDirection.credit,
            )!,
        occurredAt: transaction.occurredAt,
        postedAt: transaction.postedAt,
        counterpartyName: transaction.counterpartyName,
        note: transaction.note,
        sourceKind: transaction.sourceKind,
      );

  ReceivableCollectionInstruction _resolveCollection(
    Transaction transaction,
    Map<String, Account> accountsById,
  ) => ReceivableCollectionInstruction(
    principal:
        _detailAmount(
          transaction,
          TransactionDetailType.receivableCollectionPrincipal,
        )!,
    interest:
        _detailAmount(
          transaction,
          TransactionDetailType.receivableCollectionInterest,
        ) ??
        Money.zero(),
    receivableAccountId:
        _entryForUsage(
          transaction,
          accountsById: accountsById,
          direction: EntryDirection.credit,
          usage: AccountUsage.receivable,
        ) ??
        _entryForDetailAmount(
          transaction,
          detailType: TransactionDetailType.receivableCollectionPrincipal,
          direction: EntryDirection.credit,
        )!,
    receiveAccountId:
        _entryForUsage(
          transaction,
          accountsById: accountsById,
          direction: EntryDirection.debit,
          usage: AccountUsage.fund,
        ) ??
        _firstEntryAccount(transaction, direction: EntryDirection.debit)!,
    occurredAt: transaction.occurredAt,
    postedAt: transaction.postedAt,
    counterpartyName: transaction.counterpartyName,
    note: transaction.note,
    sourceKind: transaction.sourceKind,
  );

  String? _entryForUsage(
    Transaction transaction, {
    required Map<String, Account> accountsById,
    required EntryDirection direction,
    required AccountUsage usage,
  }) {
    if (accountsById.isEmpty) return null;
    String? match;
    for (final entry in transaction.entries) {
      final account = accountsById[entry.accountId];
      if (entry.direction != direction ||
          account == null ||
          !accountMatchesUsage(account, usage)) {
        continue;
      }
      if (match != null) return null;
      match = entry.accountId;
    }
    return match;
  }

  BadDebtInstruction _resolveBadDebt(Transaction transaction) =>
      BadDebtInstruction(
        amount: transaction.primaryAmount,
        receivableAccountId:
            _entryForDetailAmount(
              transaction,
              detailType: TransactionDetailType.badDebtMain,
              direction: EntryDirection.credit,
            )!,
        occurredAt: transaction.occurredAt,
        postedAt: transaction.postedAt,
        counterpartyName: transaction.counterpartyName,
        note: transaction.note,
        sourceKind: transaction.sourceKind,
      );

  DebtReliefInstruction _resolveDebtRelief(Transaction transaction) =>
      DebtReliefInstruction(
        amount: transaction.primaryAmount,
        liabilityAccountId:
            _entryForDetailAmount(
              transaction,
              detailType: TransactionDetailType.debtReliefMain,
              direction: EntryDirection.debit,
            )!,
        occurredAt: transaction.occurredAt,
        postedAt: transaction.postedAt,
        counterpartyName: transaction.counterpartyName,
        note: transaction.note,
        sourceKind: transaction.sourceKind,
      );

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
