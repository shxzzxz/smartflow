import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/money/money.dart';
import '../../entity/account.dart';
import '../../entity/entry.dart';
import '../../entity/transaction.dart';
import '../../entity/transaction_detail_record.dart';
import '../../valobj/ledger_enum.dart';
import '../../valobj/ledger_violation_reason.dart';
import '../../valobj/posting_instruction.dart';
import 'posting_rule.dart';

class PostingEngine {
  const PostingEngine({required IdGenerator idGenerator})
    : _idGenerator = idGenerator;

  final IdGenerator _idGenerator;

  Transaction create(PostingInstruction instruction) {
    return switch (instruction) {
      ExpenseInstruction i => createExpense(i),
      IncomeInstruction i => createIncome(i),
      ReimbursementAdvanceInstruction i => createReimbursementAdvance(i),
      TransferInstruction i => createTransfer(i),
      RepaymentInstruction i => createRepayment(i),
      BorrowingInstruction i => createBorrowing(i),
    };
  }

  Transaction createExpense(ExpenseInstruction instruction) {
    if (instruction.amount.minorUnits <= 0) {
      return LedgerViolationReason.expenseAmountNotPositive.throwException(
        message: 'Expense amount must be positive.',
      );
    }
    final transactionId = _idGenerator.newId();
    return _validated(
      Transaction(
        id: transactionId,
        businessPurpose: BusinessPurpose.dailyExpense,
        occurredAt: instruction.occurredAt,
        primaryAmount: instruction.amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        isExcludedFromStats: instruction.isExcludedFromStats,
        isExcludedFromBudget: instruction.isExcludedFromBudget,
        sourceKind: instruction.sourceKind,
        ownership: instruction.ownership,
        details: [
          _detail(
            transactionId: transactionId,
            lineNo: 1,
            type: TransactionDetailType.primaryExpense,
            amount: instruction.amount,
          ),
        ],
        entries: [
          _entry(
            transactionId: transactionId,
            accountId: instruction.expenseAccountId,
            direction: EntryDirection.debit,
            amount: instruction.amount,
          ),
          _entry(
            transactionId: transactionId,
            accountId: instruction.paidFromAccountId,
            direction: EntryDirection.credit,
            amount: instruction.amount,
          ),
        ],
      ),
    );
  }

  Transaction createIncome(IncomeInstruction instruction) {
    if (instruction.amount.minorUnits <= 0) {
      return LedgerViolationReason.incomeAmountNotPositive.throwException(
        message: 'Income amount must be positive.',
      );
    }
    final transactionId = _idGenerator.newId();
    return _validated(
      Transaction(
        id: transactionId,
        businessPurpose: BusinessPurpose.dailyIncome,
        occurredAt: instruction.occurredAt,
        primaryAmount: instruction.amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        isExcludedFromStats: instruction.isExcludedFromStats,
        isExcludedFromBudget: false,
        sourceKind: instruction.sourceKind,
        ownership: instruction.ownership,
        details: [
          _detail(
            transactionId: transactionId,
            lineNo: 1,
            type: TransactionDetailType.primaryIncome,
            amount: instruction.amount,
          ),
        ],
        entries: [
          _entry(
            transactionId: transactionId,
            accountId: instruction.receiveAccountId,
            direction: EntryDirection.debit,
            amount: instruction.amount,
          ),
          _entry(
            transactionId: transactionId,
            accountId: instruction.incomeAccountId,
            direction: EntryDirection.credit,
            amount: instruction.amount,
          ),
        ],
      ),
    );
  }

  Transaction createReimbursementAdvance(
    ReimbursementAdvanceInstruction instruction,
  ) {
    if (instruction.amount.minorUnits <= 0) {
      return LedgerViolationReason.reimbursementAmountNotPositive
          .throwException(
            message: 'Reimbursement advance amount must be positive.',
          );
    }
    final transactionId = _idGenerator.newId();
    return _validated(
      Transaction(
        id: transactionId,
        businessPurpose: BusinessPurpose.reimbursementAdvance,
        occurredAt: instruction.occurredAt,
        primaryAmount: instruction.amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        reimbursementExpenseAccountId: instruction.expenseAccountId,
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
        sourceKind: instruction.sourceKind,
        ownership: instruction.ownership,
        details: [
          _detail(
            transactionId: transactionId,
            lineNo: 1,
            type: TransactionDetailType.reimbursementAdvanceMain,
            amount: instruction.amount,
          ),
        ],
        entries: [
          _entry(
            transactionId: transactionId,
            accountId: instruction.receivableAccountId,
            direction: EntryDirection.debit,
            amount: instruction.amount,
          ),
          _entry(
            transactionId: transactionId,
            accountId: instruction.paidFromAccountId,
            direction: EntryDirection.credit,
            amount: instruction.amount,
          ),
        ],
      ),
    );
  }

  Transaction createRefund({
    required RefundInstruction instruction,
    required Transaction parent,
    required String refundOffsetAccountId,
  }) {
    if (instruction.amount.minorUnits <= 0) {
      return LedgerViolationReason.refundAmountNotPositive.throwException(
        message: 'Refund amount must be positive.',
      );
    }
    final transactionId = _idGenerator.newId();
    return _validated(
      Transaction(
        id: transactionId,
        parentTransactionId: parent.id,
        businessPurpose: BusinessPurpose.refund,
        occurredAt: instruction.occurredAt,
        primaryAmount: instruction.amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        isExcludedFromStats: parent.isExcludedFromStats,
        isExcludedFromBudget: parent.isExcludedFromBudget,
        sourceKind: parent.sourceKind,
        ownership: parent.ownership,
        details: [
          _detail(
            transactionId: transactionId,
            lineNo: 1,
            type: TransactionDetailType.refundMain,
            amount: instruction.amount,
          ),
        ],
        entries: [
          _entry(
            transactionId: transactionId,
            accountId: instruction.refundToAccountId,
            direction: EntryDirection.debit,
            amount: instruction.amount,
          ),
          _entry(
            transactionId: transactionId,
            accountId: refundOffsetAccountId,
            direction: EntryDirection.credit,
            amount: instruction.amount,
          ),
        ],
      ),
    );
  }

  Transaction createTransfer(
    TransferInstruction instruction, {
    String? feeExpenseAccountId,
  }) {
    final fee = instruction.feeAmount;
    final hasFee = fee != null && fee.minorUnits > 0;
    if (instruction.amount.minorUnits <= 0) {
      return LedgerViolationReason.transferAmountNotPositive.throwException(
        message: 'Transfer amount must be positive.',
      );
    }
    if (instruction.fromAccountId == instruction.toAccountId) {
      return LedgerViolationReason.transferAccountsMustDiffer.throwException(
        message: 'Transfer source and target account must differ.',
      );
    }
    if (fee != null && fee.minorUnits < 0) {
      return LedgerViolationReason.transferFeeNegative.throwException(
        message: 'Transfer fee cannot be negative.',
      );
    }
    if (hasFee && feeExpenseAccountId == null) {
      return LedgerViolationReason.transferFeeAccountRequired.throwException(
        message: 'Transfer fee account is required.',
      );
    }

    final transactionId = _idGenerator.newId();
    final totalPaid = hasFee ? instruction.amount + fee : instruction.amount;
    return _validated(
      Transaction(
        id: transactionId,
        businessPurpose: BusinessPurpose.transfer,
        occurredAt: instruction.occurredAt,
        primaryAmount: instruction.amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
        sourceKind: instruction.sourceKind,
        details: [
          _detail(
            transactionId: transactionId,
            lineNo: 1,
            type: TransactionDetailType.transferMain,
            amount: instruction.amount,
          ),
          if (hasFee)
            _detail(
              transactionId: transactionId,
              lineNo: 2,
              type: TransactionDetailType.transferFee,
              amount: fee,
            ),
        ],
        entries: [
          _entry(
            transactionId: transactionId,
            accountId: instruction.toAccountId,
            direction: EntryDirection.debit,
            amount: instruction.amount,
          ),
          if (hasFee)
            _entry(
              transactionId: transactionId,
              accountId: feeExpenseAccountId!,
              direction: EntryDirection.debit,
              amount: fee,
            ),
          _entry(
            transactionId: transactionId,
            accountId: instruction.fromAccountId,
            direction: EntryDirection.credit,
            amount: totalPaid,
          ),
        ],
      ),
    );
  }

  Transaction createReimbursementReceipt({
    required ReimbursementReceiptInstruction instruction,
    required Transaction advance,
  }) {
    if (instruction.amount.minorUnits <= 0) {
      return LedgerViolationReason.reimbursementAmountNotPositive
          .throwException(message: 'Receipt amount must be positive.');
    }
    final transactionId = _idGenerator.newId();
    return _validated(
      Transaction(
        id: transactionId,
        parentTransactionId: advance.id,
        businessPurpose: BusinessPurpose.reimbursementReceipt,
        occurredAt: instruction.occurredAt,
        primaryAmount: instruction.amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        isExcludedFromStats: advance.isExcludedFromStats,
        isExcludedFromBudget: advance.isExcludedFromBudget,
        sourceKind: advance.sourceKind,
        ownership: advance.ownership,
        details: [
          _detail(
            transactionId: transactionId,
            lineNo: 1,
            type: TransactionDetailType.reimbursementReceiptMain,
            amount: instruction.amount,
          ),
        ],
        entries: [
          _entry(
            transactionId: transactionId,
            accountId: instruction.receiveAccountId,
            direction: EntryDirection.debit,
            amount: instruction.amount,
          ),
          _entry(
            transactionId: transactionId,
            accountId: instruction.receivableAccountId,
            direction: EntryDirection.credit,
            amount: instruction.amount,
          ),
        ],
      ),
    );
  }

  Transaction createRepayment(
    RepaymentInstruction instruction, {
    String? interestExpenseAccountId,
    String? feeExpenseAccountId,
    String? discountIncomeAccountId,
  }) {
    if (instruction.principal.minorUnits <= 0) {
      return LedgerViolationReason.repaymentPrincipalNotPositive.throwException(
        message: 'Repayment principal must be positive.',
      );
    }
    final interest = instruction.interest;
    final fee = instruction.fee;
    final discount = instruction.discount;
    final hasInterest = interest != null && interest.minorUnits > 0;
    final hasFee = fee != null && fee.minorUnits > 0;
    final hasDiscount = discount != null && discount.minorUnits > 0;
    if (hasInterest && interestExpenseAccountId == null) {
      return LedgerViolationReason.repaymentInterestAccountMissing
          .throwException(
            message: 'Interest expense system account is required.',
          );
    }
    if (hasFee && feeExpenseAccountId == null) {
      return LedgerViolationReason.repaymentFeeAccountMissing.throwException(
        message: 'Fee expense system account is required.',
      );
    }
    if (hasDiscount && discountIncomeAccountId == null) {
      return LedgerViolationReason.repaymentDiscountAccountMissing
          .throwException(
            message: 'Discount income system account is required.',
          );
    }
    final totalPaid =
        instruction.principal +
        (hasInterest ? interest : Money.zero()) +
        (hasFee ? fee : Money.zero()) -
        (hasDiscount ? discount : Money.zero());
    if (totalPaid.minorUnits <= 0) {
      return LedgerViolationReason.repaymentTotalPaidNotPositive.throwException(
        message: 'Repayment total paid must be positive.',
      );
    }

    var lineNo = 1;
    final transactionId = _idGenerator.newId();
    return _validated(
      Transaction(
        id: transactionId,
        businessPurpose: BusinessPurpose.debtRepayment,
        occurredAt: instruction.occurredAt,
        primaryAmount: totalPaid,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
        sourceKind: instruction.sourceKind,
        ownership: instruction.ownership,
        details: [
          _detail(
            transactionId: transactionId,
            lineNo: lineNo++,
            type: TransactionDetailType.repaymentPrincipal,
            amount: instruction.principal,
          ),
          if (hasInterest)
            _detail(
              transactionId: transactionId,
              lineNo: lineNo++,
              type: TransactionDetailType.repaymentInterest,
              amount: interest,
            ),
          if (hasFee)
            _detail(
              transactionId: transactionId,
              lineNo: lineNo++,
              type: TransactionDetailType.repaymentFee,
              amount: fee,
            ),
          if (hasDiscount)
            _detail(
              transactionId: transactionId,
              lineNo: lineNo++,
              type: TransactionDetailType.repaymentDiscount,
              amount: discount,
            ),
        ],
        entries: [
          _entry(
            transactionId: transactionId,
            accountId: instruction.liabilityAccountId,
            direction: EntryDirection.debit,
            amount: instruction.principal,
          ),
          if (hasInterest)
            _entry(
              transactionId: transactionId,
              accountId: interestExpenseAccountId!,
              direction: EntryDirection.debit,
              amount: interest,
            ),
          if (hasFee)
            _entry(
              transactionId: transactionId,
              accountId: feeExpenseAccountId!,
              direction: EntryDirection.debit,
              amount: fee,
            ),
          if (hasDiscount)
            _entry(
              transactionId: transactionId,
              accountId: discountIncomeAccountId!,
              direction: EntryDirection.credit,
              amount: discount,
            ),
          _entry(
            transactionId: transactionId,
            accountId: instruction.paidFromAccountId,
            direction: EntryDirection.credit,
            amount: totalPaid,
          ),
        ],
      ),
    );
  }

  Transaction createBorrowing(BorrowingInstruction instruction) {
    if (instruction.amount.minorUnits <= 0) {
      return LedgerViolationReason.borrowingAmountNotPositive.throwException(
        message: 'Borrowing amount must be positive.',
      );
    }
    final transactionId = _idGenerator.newId();
    return _validated(
      Transaction(
        id: transactionId,
        businessPurpose: BusinessPurpose.borrowing,
        occurredAt: instruction.occurredAt,
        primaryAmount: instruction.amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
        sourceKind: instruction.sourceKind,
        ownership: instruction.ownership,
        details: [
          _detail(
            transactionId: transactionId,
            lineNo: 1,
            type: TransactionDetailType.borrowingPrincipal,
            amount: instruction.amount,
          ),
        ],
        entries: [
          _entry(
            transactionId: transactionId,
            accountId: instruction.receiveAccountId,
            direction: EntryDirection.debit,
            amount: instruction.amount,
          ),
          _entry(
            transactionId: transactionId,
            accountId: instruction.liabilityAccountId,
            direction: EntryDirection.credit,
            amount: instruction.amount,
          ),
        ],
      ),
    );
  }

  Transaction createOpeningBalance({
    required OpeningBalanceInstruction instruction,
    required Account account,
    required String equityAccountId,
  }) {
    if (account.archivedAt != null) {
      return LedgerViolationReason.accountArchived.throwException(
        message: 'Cannot initialize archived account.',
      );
    }
    if (instruction.amount.minorUnits == 0) {
      return LedgerViolationReason.openingBalanceZero.throwException(
        message: 'Opening balance amount cannot be zero.',
      );
    }
    final amount = instruction.amount.abs();
    final accountDirection = directionForBalanceDelta(
      accountType: account.type,
      deltaMinor: instruction.amount.minorUnits,
    );
    final equityDirection =
        accountDirection == EntryDirection.debit
            ? EntryDirection.credit
            : EntryDirection.debit;
    final transactionId = _idGenerator.newId();
    return _validated(
      Transaction(
        id: transactionId,
        businessPurpose: BusinessPurpose.openingBalance,
        occurredAt: instruction.occurredAt,
        primaryAmount: amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
        sourceKind: SourceKind.manual,
        details: [
          _detail(
            transactionId: transactionId,
            lineNo: 1,
            type: TransactionDetailType.openingBalanceMain,
            amount: amount,
          ),
        ],
        entries: [
          _entry(
            transactionId: transactionId,
            accountId: account.id,
            direction: accountDirection,
            amount: amount,
          ),
          _entry(
            transactionId: transactionId,
            accountId: equityAccountId,
            direction: equityDirection,
            amount: amount,
          ),
        ],
      ),
    );
  }

  Transaction createBalanceAdjustment({
    required BalanceAdjustmentInstruction instruction,
    required Account account,
    required Money signedDelta,
    required String equityAccountId,
  }) {
    final amount = signedDelta.abs();
    final accountDirection = directionForBalanceDelta(
      accountType: account.type,
      deltaMinor: signedDelta.minorUnits,
    );
    final equityDirection =
        accountDirection == EntryDirection.debit
            ? EntryDirection.credit
            : EntryDirection.debit;
    final transactionId = _idGenerator.newId();
    return _validated(
      Transaction(
        id: transactionId,
        businessPurpose: BusinessPurpose.balanceAdjustment,
        occurredAt: instruction.occurredAt,
        primaryAmount: amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
        sourceKind: SourceKind.manual,
        details: [
          _detail(
            transactionId: transactionId,
            lineNo: 1,
            type: TransactionDetailType.balanceAdjustmentMain,
            amount: amount,
          ),
        ],
        entries: [
          _entry(
            transactionId: transactionId,
            accountId: account.id,
            direction: accountDirection,
            amount: amount,
          ),
          _entry(
            transactionId: transactionId,
            accountId: equityAccountId,
            direction: equityDirection,
            amount: amount,
          ),
        ],
      ),
    );
  }

  Transaction createReimbursementClose({
    required ReimbursementCloseInstruction instruction,
    required Transaction advance,
    required Money outstanding,
    required String? gapIncomeAccountId,
  }) {
    final actual = instruction.actualReceivedAmount;
    if (actual.minorUnits < 0) {
      return LedgerViolationReason.reimbursementCloseAmountNegative
          .throwException(message: 'Received amount cannot be negative.');
    }
    final gap = actual - outstanding;
    if (gap.minorUnits > 0 && gapIncomeAccountId == null) {
      return LedgerViolationReason.reimbursementGapIncomeRequired
          .throwException(message: 'Gap income account is required.');
    }

    final transactionId = _idGenerator.newId();
    final hasOutstanding = outstanding.minorUnits > 0;
    final details = <TransactionDetailRecord>[
      if (hasOutstanding)
        _detail(
          transactionId: transactionId,
          lineNo: 1,
          type: TransactionDetailType.reimbursementCloseMain,
          amount: outstanding,
        ),
    ];
    if (gap.minorUnits > 0) {
      details.add(
        _detail(
          transactionId: transactionId,
          lineNo: 2,
          type: TransactionDetailType.reimbursementGapIncome,
          amount: gap,
        ),
      );
    } else if (gap.minorUnits < 0) {
      details.add(
        _detail(
          transactionId: transactionId,
          lineNo: 2,
          type: TransactionDetailType.reimbursementGapExpense,
          amount: -gap,
        ),
      );
    }

    final entries = <Entry>[
      if (actual.minorUnits > 0)
        _entry(
          transactionId: transactionId,
          accountId: instruction.receiveAccountId,
          direction: EntryDirection.debit,
          amount: actual,
        ),
      if (hasOutstanding)
        _entry(
          transactionId: transactionId,
          accountId: instruction.receivableAccountId,
          direction: EntryDirection.credit,
          amount: outstanding,
        ),
    ];
    if (gap.minorUnits > 0) {
      entries.add(
        _entry(
          transactionId: transactionId,
          accountId: gapIncomeAccountId!,
          direction: EntryDirection.credit,
          amount: gap,
        ),
      );
    } else if (gap.minorUnits < 0) {
      entries.add(
        _entry(
          transactionId: transactionId,
          accountId: advance.reimbursementExpenseAccountId!,
          direction: EntryDirection.debit,
          amount: -gap,
        ),
      );
    }

    return _validated(
      Transaction(
        id: transactionId,
        parentTransactionId: advance.id,
        businessPurpose: BusinessPurpose.reimbursementClose,
        occurredAt: instruction.occurredAt,
        primaryAmount: actual.minorUnits > 0 ? actual : outstanding,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        isExcludedFromStats: advance.isExcludedFromStats,
        isExcludedFromBudget: advance.isExcludedFromBudget,
        sourceKind: advance.sourceKind,
        ownership: advance.ownership,
        details: details,
        entries: entries,
      ),
    );
  }

  Transaction _validated(Transaction transaction) {
    transaction.validateSelf();
    return transaction;
  }

  TransactionDetailRecord _detail({
    required String transactionId,
    required int lineNo,
    required TransactionDetailType type,
    required Money amount,
  }) {
    return TransactionDetailRecord(
      id: _idGenerator.newId(),
      transactionId: transactionId,
      lineNo: lineNo,
      type: type,
      amount: amount,
    );
  }

  Entry _entry({
    required String transactionId,
    required String accountId,
    required EntryDirection direction,
    required Money amount,
  }) {
    return Entry(
      id: _idGenerator.newId(),
      transactionId: transactionId,
      accountId: accountId,
      direction: direction,
      amount: amount,
    );
  }
}
