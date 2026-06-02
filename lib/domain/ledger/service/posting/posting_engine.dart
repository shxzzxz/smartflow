import 'package:smartflow/core/error/failure.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/result/result.dart';
import '../../entity/account.dart';
import '../../entity/entry.dart';
import '../../entity/transaction.dart';
import '../../entity/transaction_detail_record.dart';
import '../../valobj/ledger_enum.dart';
import '../../valobj/posting_instruction.dart';
import '../../valobj/posting_result.dart';
import 'posting_rule.dart';

class PostingEngine {
  const PostingEngine({required IdGenerator idGenerator})
    : _idGenerator = idGenerator;

  final IdGenerator _idGenerator;

  Result<Transaction> create(PostingInstruction instruction) {
    return switch (instruction) {
      ExpenseInstruction i => createExpense(i),
      IncomeInstruction i => createIncome(i),
      ReimbursementAdvanceInstruction i => createReimbursementAdvance(i),
      TransferInstruction i => createTransfer(i),
      RepaymentInstruction i => createRepayment(i),
      BorrowingInstruction i => createBorrowing(i),
    };
  }

  Result<Transaction> createExpense(ExpenseInstruction instruction) {
    if (instruction.amount.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'expense_amount_not_positive',
          message: 'Expense amount must be positive.',
        ),
      );
    }
    final transactionId = _idGenerator.newId();
    return _validated(
      Transaction(
        id: transactionId,
        rootTransactionId: transactionId,
        businessPurpose: BusinessPurpose.dailyExpense,
        occurredAt: instruction.occurredAt,
        primaryAmount: instruction.amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        mutationKind: MutationKind.original,
        businessState: BusinessState.current,
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

  Result<Transaction> createIncome(IncomeInstruction instruction) {
    if (instruction.amount.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'income_amount_not_positive',
          message: 'Income amount must be positive.',
        ),
      );
    }
    final transactionId = _idGenerator.newId();
    return _validated(
      Transaction(
        id: transactionId,
        rootTransactionId: transactionId,
        businessPurpose: BusinessPurpose.dailyIncome,
        occurredAt: instruction.occurredAt,
        primaryAmount: instruction.amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        mutationKind: MutationKind.original,
        businessState: BusinessState.current,
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

  Result<Transaction> createReimbursementAdvance(
    ReimbursementAdvanceInstruction instruction,
  ) {
    if (instruction.amount.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_amount_not_positive',
          message: 'Reimbursement advance amount must be positive.',
        ),
      );
    }
    final transactionId = _idGenerator.newId();
    return _validated(
      Transaction(
        id: transactionId,
        rootTransactionId: transactionId,
        businessPurpose: BusinessPurpose.reimbursementAdvance,
        occurredAt: instruction.occurredAt,
        primaryAmount: instruction.amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        reimbursementExpenseAccountId: instruction.expenseAccountId,
        mutationKind: MutationKind.original,
        businessState: BusinessState.current,
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

  Result<Transaction> createRefund({
    required RefundInstruction instruction,
    required Transaction parent,
    required String refundOffsetAccountId,
  }) {
    if (instruction.amount.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'refund_amount_not_positive',
          message: 'Refund amount must be positive.',
        ),
      );
    }
    final transactionId = _idGenerator.newId();
    return _validated(
      Transaction(
        id: transactionId,
        rootTransactionId: parent.rootTransactionId,
        parentTransactionId: parent.id,
        businessPurpose: BusinessPurpose.refund,
        occurredAt: instruction.occurredAt,
        primaryAmount: instruction.amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        mutationKind: MutationKind.original,
        businessState: BusinessState.current,
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

  Result<Transaction> createTransfer(
    TransferInstruction instruction, {
    String? feeExpenseAccountId,
  }) {
    final fee = instruction.feeAmount;
    final hasFee = fee != null && fee.minorUnits > 0;
    if (instruction.amount.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'transfer_amount_not_positive',
          message: 'Transfer amount must be positive.',
        ),
      );
    }
    if (instruction.fromAccountId == instruction.toAccountId) {
      return const Result.failure(
        Failure(
          code: 'transfer_accounts_must_differ',
          message: 'Transfer source and target account must differ.',
        ),
      );
    }
    if (fee != null && fee.minorUnits < 0) {
      return const Result.failure(
        Failure(
          code: 'transfer_fee_negative',
          message: 'Transfer fee cannot be negative.',
        ),
      );
    }
    if (hasFee && feeExpenseAccountId == null) {
      return const Result.failure(
        Failure(
          code: 'transfer_fee_account_required',
          message: 'Transfer fee account is required.',
        ),
      );
    }

    final transactionId = _idGenerator.newId();
    final totalPaid = hasFee ? instruction.amount + fee : instruction.amount;
    return _validated(
      Transaction(
        id: transactionId,
        rootTransactionId: transactionId,
        businessPurpose: BusinessPurpose.transfer,
        occurredAt: instruction.occurredAt,
        primaryAmount: instruction.amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        mutationKind: MutationKind.original,
        businessState: BusinessState.current,
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

  Result<Transaction> createReimbursementReceipt({
    required ReimbursementReceiptInstruction instruction,
    required Transaction advance,
  }) {
    if (instruction.amount.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_amount_not_positive',
          message: 'Receipt amount must be positive.',
        ),
      );
    }
    final transactionId = _idGenerator.newId();
    return _validated(
      Transaction(
        id: transactionId,
        rootTransactionId: advance.rootTransactionId,
        parentTransactionId: advance.id,
        businessPurpose: BusinessPurpose.reimbursementReceipt,
        occurredAt: instruction.occurredAt,
        primaryAmount: instruction.amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        mutationKind: MutationKind.original,
        businessState: BusinessState.current,
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
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

  Result<Transaction> createRepayment(
    RepaymentInstruction instruction, {
    String? interestExpenseAccountId,
    String? feeExpenseAccountId,
    String? discountIncomeAccountId,
  }) {
    if (instruction.principal.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'repayment_principal_not_positive',
          message: 'Repayment principal must be positive.',
        ),
      );
    }
    final interest = instruction.interest;
    final fee = instruction.fee;
    final discount = instruction.discount;
    final hasInterest = interest != null && interest.minorUnits > 0;
    final hasFee = fee != null && fee.minorUnits > 0;
    final hasDiscount = discount != null && discount.minorUnits > 0;
    if (hasInterest && interestExpenseAccountId == null) {
      return const Result.failure(
        Failure(
          code: 'repayment_interest_account_missing',
          message: 'Interest expense system account is required.',
        ),
      );
    }
    if (hasFee && feeExpenseAccountId == null) {
      return const Result.failure(
        Failure(
          code: 'repayment_fee_account_missing',
          message: 'Fee expense system account is required.',
        ),
      );
    }
    if (hasDiscount && discountIncomeAccountId == null) {
      return const Result.failure(
        Failure(
          code: 'repayment_discount_account_missing',
          message: 'Discount income system account is required.',
        ),
      );
    }
    final totalPaid =
        instruction.principal +
        (hasInterest ? interest : Money.zero()) +
        (hasFee ? fee : Money.zero()) -
        (hasDiscount ? discount : Money.zero());
    if (totalPaid.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'repayment_total_paid_not_positive',
          message: 'Repayment total paid must be positive.',
        ),
      );
    }

    var lineNo = 1;
    final transactionId = _idGenerator.newId();
    return _validated(
      Transaction(
        id: transactionId,
        rootTransactionId: transactionId,
        businessPurpose: BusinessPurpose.debtRepayment,
        occurredAt: instruction.occurredAt,
        primaryAmount: totalPaid,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        mutationKind: MutationKind.original,
        businessState: BusinessState.current,
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

  Result<Transaction> createBorrowing(BorrowingInstruction instruction) {
    if (instruction.amount.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'borrowing_amount_not_positive',
          message: 'Borrowing amount must be positive.',
        ),
      );
    }
    final transactionId = _idGenerator.newId();
    return _validated(
      Transaction(
        id: transactionId,
        rootTransactionId: transactionId,
        businessPurpose: BusinessPurpose.borrowing,
        occurredAt: instruction.occurredAt,
        primaryAmount: instruction.amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        mutationKind: MutationKind.original,
        businessState: BusinessState.current,
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

  Result<Transaction> createOpeningBalance({
    required OpeningBalanceInstruction instruction,
    required Account account,
    required String equityAccountId,
  }) {
    if (account.archivedAt != null) {
      return const Result.failure(
        Failure(
          code: 'account_archived',
          message: 'Cannot initialize archived account.',
        ),
      );
    }
    if (instruction.amount.minorUnits == 0) {
      return const Result.failure(
        Failure(
          code: 'opening_balance_zero',
          message: 'Opening balance amount cannot be zero.',
        ),
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
        rootTransactionId: transactionId,
        businessPurpose: BusinessPurpose.openingBalance,
        occurredAt: instruction.occurredAt,
        primaryAmount: amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        mutationKind: MutationKind.original,
        businessState: BusinessState.current,
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

  Result<Transaction> createBalanceAdjustment({
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
        rootTransactionId: transactionId,
        businessPurpose: BusinessPurpose.balanceAdjustment,
        occurredAt: instruction.occurredAt,
        primaryAmount: amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        mutationKind: MutationKind.original,
        businessState: BusinessState.current,
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

  Result<Transaction> createReimbursementClose({
    required ReimbursementCloseInstruction instruction,
    required Transaction advance,
    required Money outstanding,
    required String? gapIncomeAccountId,
  }) {
    final actual = instruction.actualReceivedAmount;
    if (actual.minorUnits < 0) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_close_amount_negative',
          message: 'Received amount cannot be negative.',
        ),
      );
    }
    final gap = actual - outstanding;
    if (gap.minorUnits > 0 && gapIncomeAccountId == null) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_gap_income_required',
          message: 'Gap income account is required.',
        ),
      );
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
        rootTransactionId: advance.rootTransactionId,
        parentTransactionId: advance.id,
        businessPurpose: BusinessPurpose.reimbursementClose,
        occurredAt: instruction.occurredAt,
        primaryAmount: actual.minorUnits > 0 ? actual : outstanding,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        mutationKind: MutationKind.original,
        businessState: BusinessState.current,
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
        sourceKind: advance.sourceKind,
        ownership: advance.ownership,
        details: details,
        entries: entries,
      ),
    );
  }

  Result<TransactionReplacement> createReplacement({
    required Transaction original,
    required Transaction replacement,
    required MutationReason reason,
  }) {
    final replaced = original.copyWith(businessState: BusinessState.replaced);
    final reversalId = _idGenerator.newId();
    final reversal = Transaction(
      id: reversalId,
      rootTransactionId: original.rootTransactionId,
      businessPurpose: original.businessPurpose,
      occurredAt: original.occurredAt,
      primaryAmount: -original.primaryAmount,
      counterpartyName: original.counterpartyName,
      note: original.note,
      parentTransactionId: original.parentTransactionId,
      reimbursementExpenseAccountId: original.reimbursementExpenseAccountId,
      mutationKind: MutationKind.reversal,
      mutationPreviousTransactionId: original.id,
      mutationReason: reason,
      businessState: BusinessState.compensation,
      isExcludedFromStats: original.isExcludedFromStats,
      isExcludedFromBudget: original.isExcludedFromBudget,
      sourceKind: original.sourceKind,
      ownership: original.ownership,
      details: [
        for (final detail in original.details)
          _detail(
            transactionId: reversalId,
            lineNo: detail.lineNo,
            type: detail.type,
            amount: -detail.amount,
          ),
      ],
      entries: [
        for (final entry in original.entries)
          _entry(
            transactionId: reversalId,
            accountId: entry.accountId,
            direction: entry.direction,
            amount: -entry.amount,
          ),
      ],
    );
    final correction = replacement.copyWith(
      rootTransactionId: original.rootTransactionId,
      // 取 replacement 的 parent:子交易迁移时新候选已挂到新父,
      // 用 original 会让更正后的子交易仍指向被红冲的旧父。
      parentTransactionId: replacement.parentTransactionId,
      reimbursementExpenseAccountId:
          replacement.reimbursementExpenseAccountId ??
          original.reimbursementExpenseAccountId,
      mutationKind: MutationKind.correction,
      mutationPreviousTransactionId: reversal.id,
      mutationReason: null,
      businessState: BusinessState.current,
      sourceKind: original.sourceKind,
      ownership: original.ownership,
    );

    final reversalFailure = reversal.validateSelf(allowNegativeAmounts: true);
    if (reversalFailure != null) return Result.failure(reversalFailure);
    final correctionFailure = correction.validateSelf();
    if (correctionFailure != null) return Result.failure(correctionFailure);

    return Result.success(
      TransactionReplacement(
        replacedTransaction: replaced,
        reversalTransaction: reversal,
        correctionTransaction: correction,
      ),
    );
  }

  Result<TransactionCancellation> createCancellation({
    required Transaction original,
    required MutationReason reason,
  }) {
    final canceled = original.copyWith(businessState: BusinessState.canceled);
    final reversalId = _idGenerator.newId();
    final reversal = Transaction(
      id: reversalId,
      rootTransactionId: original.rootTransactionId,
      businessPurpose: original.businessPurpose,
      occurredAt: original.occurredAt,
      primaryAmount: -original.primaryAmount,
      counterpartyName: original.counterpartyName,
      note: original.note,
      parentTransactionId: original.parentTransactionId,
      reimbursementExpenseAccountId: original.reimbursementExpenseAccountId,
      mutationKind: MutationKind.reversal,
      mutationPreviousTransactionId: original.id,
      mutationReason: reason,
      businessState: BusinessState.compensation,
      isExcludedFromStats: original.isExcludedFromStats,
      isExcludedFromBudget: original.isExcludedFromBudget,
      sourceKind: original.sourceKind,
      ownership: original.ownership,
      details: [
        for (final detail in original.details)
          _detail(
            transactionId: reversalId,
            lineNo: detail.lineNo,
            type: detail.type,
            amount: -detail.amount,
          ),
      ],
      entries: [
        for (final entry in original.entries)
          _entry(
            transactionId: reversalId,
            accountId: entry.accountId,
            direction: entry.direction,
            amount: -entry.amount,
          ),
      ],
    );
    final reversalFailure = reversal.validateSelf(allowNegativeAmounts: true);
    if (reversalFailure != null) return Result.failure(reversalFailure);
    return Result.success(
      TransactionCancellation(
        canceledTransaction: canceled,
        reversalTransaction: reversal,
      ),
    );
  }

  Result<Transaction> _validated(Transaction transaction) {
    final failure = transaction.validateSelf();
    return failure == null
        ? Result.success(transaction)
        : Result.failure(failure);
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
