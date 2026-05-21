import '../../../core/errors/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../../../core/result/result.dart';
import '../commands/transaction_commands.dart';
import '../entities/account_usage.dart';
import '../entities/transaction.dart';
import '../enums/accounting_enums.dart';
import '../ledger/poster.dart';
import '../ledger/posting_protocol.dart';
import '../repositories/account_repository.dart';
import '../repositories/posting_repository.dart';
import '../repositories/system_account_resolver.dart';
import '../repositories/transaction_query_repository.dart';
import '../views/transaction_views.dart';

CreatedTransactionResult _toCreated(PostTransactionResult post) =>
    CreatedTransactionResult(
      transactionId: post.transactionId,
      rootTransactionId: post.rootTransactionId,
    );

abstract interface class TransactionService {
  Future<Result<CreatedTransactionResult>> createExpense(
    CreateExpenseCommand command,
  );

  Future<Result<CreatedTransactionResult>> createIncome(
    CreateIncomeCommand command,
  );

  Future<Result<CreatedTransactionResult>> createTransfer(
    CreateTransferCommand command,
  );

  Future<Result<CreatedTransactionResult>> createRefund(
    CreateRefundCommand command,
  );

  Future<Result<CreatedTransactionResult>> createReimbursementAdvance(
    CreateReimbursementAdvanceCommand command,
  );

  Future<Result<CreatedTransactionResult>> createReimbursementReceipt(
    CreateReimbursementReceiptCommand command,
  );

  Future<Result<CreatedTransactionResult>> closeReimbursement(
    CloseReimbursementCommand command,
  );

  Future<Result<CreatedTransactionResult>> createRepayment(
    CreateRepaymentCommand command,
  );

  Future<Result<CreatedTransactionResult>> createBorrowing(
    CreateBorrowingCommand command,
  );

  Future<Result<CreatedTransactionResult>> createOpeningBalance(
    CreateOpeningBalanceCommand command,
  );

  Future<Result<CreatedTransactionResult>> adjustBalance(
    AdjustBalanceCommand command,
  );

  Future<Result<CreatedTransactionResult>> correctExpense(
    CorrectExpenseCommand command,
  );

  Future<Result<CreatedTransactionResult>> correctIncome(
    CorrectIncomeCommand command,
  );

  Future<Result<CreatedTransactionResult>> correctTransfer(
    CorrectTransferCommand command,
  );

  Future<Result<CreatedTransactionResult>> correctReimbursementAdvance(
    CorrectReimbursementAdvanceCommand command,
  );

  Future<Result<CreatedTransactionResult>> correctRefund(
    CorrectRefundCommand command,
  );

  Future<Result<CreatedTransactionResult>> correctReimbursementReceipt(
    CorrectReimbursementReceiptCommand command,
  );

  Future<Result<CreatedTransactionResult>> correctReimbursementClose(
    CorrectReimbursementCloseCommand command,
  );

  Future<Result<CreatedTransactionResult>> correctBorrowing(
    CorrectBorrowingCommand command,
  );

  Future<Result<CreatedTransactionResult>> correctRepayment(
    CorrectRepaymentCommand command,
  );

  Future<Result<void>> deleteTransaction(DeleteTransactionCommand command);

  Future<Result<void>> updateTransactionMetadata(
    UpdateTransactionMetadataCommand command,
  );

  Future<Result<void>> updateTransactionBasics(
    UpdateTransactionBasicsCommand command,
  );

  Future<Result<void>> updateTransactionOwnership(
    UpdateTransactionOwnershipCommand command,
  );
}

class TransactionServiceImpl implements TransactionService {
  const TransactionServiceImpl(
    this._postingService, {
    required AccountRepository accountRepository,
    required TransactionQueryRepository transactionQueryRepository,
    required SystemAccountResolver systemAccountResolver,
    required PostingRepository postingRepository,
  }) : _accountRepository = accountRepository,
       _queryRepository = transactionQueryRepository,
       _systemAccounts = systemAccountResolver,
       _postingRepository = postingRepository;

  Future<Result<CreatedTransactionResult>> _post(
    PostTransactionCommand command,
  ) async {
    final result = await _postingService.post(command);
    switch (result) {
      case Success(:final value):
        return Result.success(_toCreated(value));
      case FailureResult(:final failure):
        return Result.failure(failure);
    }
  }

  Future<Result<List<CreatedTransactionResult>>> _postMutation({
    required List<TransactionStateUpdate> stateUpdates,
    required List<PostTransactionCommand> commands,
  }) async {
    final result = await _postingService.postMutation(
      stateUpdates: stateUpdates,
      commands: commands,
    );
    switch (result) {
      case Success(:final value):
        return Result.success([for (final r in value) _toCreated(r)]);
      case FailureResult(:final failure):
        return Result.failure(failure);
    }
  }

  final Poster _postingService;
  final AccountRepository _accountRepository;
  final TransactionQueryRepository _queryRepository;
  final SystemAccountResolver _systemAccounts;
  final PostingRepository _postingRepository;

  @override
  Future<Result<CreatedTransactionResult>> createExpense(
    CreateExpenseCommand command,
  ) async {
    final roleFailure = await _validateAccountConstraints(
      usages: {command.paidFromAccountId: AccountUsage.settlement},
      types: {
        command.expenseAccountId: {AccountType.expense},
      },
    );
    if (roleFailure != null) {
      return Result.failure(roleFailure);
    }

    return _post(
      PostTransactionCommand(
        businessPurpose: BusinessPurpose.dailyExpense,
        occurredAt: command.occurredAt,
        currencyCode: command.amount.currency,
        primaryAmount: command.amount,
        counterpartyName: command.counterpartyName,
        note: command.note,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
        details: [
          PostTransactionDetailInput(
            lineNo: 1,
            type: TransactionDetailType.primaryExpense,
            amount: command.amount,
          ),
        ],
        entries: [
          PostEntryInput(
            accountId: command.expenseAccountId,
            direction: EntryDirection.debit,
            amount: command.amount,
          ),
          PostEntryInput(
            accountId: command.paidFromAccountId,
            direction: EntryDirection.credit,
            amount: command.amount,
          ),
        ],
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> createIncome(
    CreateIncomeCommand command,
  ) async {
    final roleFailure = await _validateAccountConstraints(
      usages: {command.receiveAccountId: AccountUsage.settlement},
      types: {
        command.incomeAccountId: {AccountType.income},
      },
    );
    if (roleFailure != null) {
      return Result.failure(roleFailure);
    }

    return _post(
      PostTransactionCommand(
        businessPurpose: BusinessPurpose.dailyIncome,
        occurredAt: command.occurredAt,
        currencyCode: command.amount.currency,
        primaryAmount: command.amount,
        counterpartyName: command.counterpartyName,
        note: command.note,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
        details: [
          PostTransactionDetailInput(
            lineNo: 1,
            type: TransactionDetailType.primaryIncome,
            amount: command.amount,
          ),
        ],
        entries: [
          PostEntryInput(
            accountId: command.receiveAccountId,
            direction: EntryDirection.debit,
            amount: command.amount,
          ),
          PostEntryInput(
            accountId: command.incomeAccountId,
            direction: EntryDirection.credit,
            amount: command.amount,
          ),
        ],
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> createTransfer(
    CreateTransferCommand command,
  ) async {
    final feeFailure = _validateTransferFee(command);
    if (feeFailure != null) {
      return Result.failure(feeFailure);
    }
    if (command.fromAccountId == command.toAccountId) {
      return const Result.failure(
        Failure(
          code: 'transfer_accounts_must_differ',
          message: 'Transfer source and target accounts must differ.',
        ),
      );
    }

    final feeAmount = command.feeAmount;
    final feeExpenseAccountId = command.feeExpenseAccountId;
    final hasFee = feeAmount != null && feeAmount.minorUnits > 0;
    final totalPaid = hasFee ? command.amount + feeAmount : command.amount;
    final accountRoles = <int, Set<AccountType>>{
      if (hasFee) feeExpenseAccountId!: {AccountType.expense},
    };
    final roleFailure = await _validateAccountConstraints(
      usages: {
        command.fromAccountId: AccountUsage.settlement,
        command.toAccountId: AccountUsage.settlement,
      },
      types: accountRoles,
    );
    if (roleFailure != null) {
      return Result.failure(roleFailure);
    }

    return _post(
      PostTransactionCommand(
        businessPurpose: BusinessPurpose.transfer,
        occurredAt: command.occurredAt,
        currencyCode: command.amount.currency,
        primaryAmount: command.amount,
        counterpartyName: command.counterpartyName,
        note: command.note,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
        details: [
          PostTransactionDetailInput(
            lineNo: 1,
            type: TransactionDetailType.transferMain,
            amount: command.amount,
          ),
          if (hasFee)
            PostTransactionDetailInput(
              lineNo: 2,
              type: TransactionDetailType.transferFee,
              amount: feeAmount,
            ),
        ],
        entries: [
          PostEntryInput(
            accountId: command.toAccountId,
            direction: EntryDirection.debit,
            amount: command.amount,
          ),
          if (hasFee)
            PostEntryInput(
              accountId: feeExpenseAccountId!,
              direction: EntryDirection.debit,
              amount: feeAmount,
            ),
          PostEntryInput(
            accountId: command.fromAccountId,
            direction: EntryDirection.credit,
            amount: totalPaid,
          ),
        ],
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> createRefund(
    CreateRefundCommand command,
  ) async {
    if (command.amount.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'refund_amount_not_positive',
          message: 'Refund amount must be positive.',
        ),
      );
    }
    final query = _queryRepository;
    final parent = await query.findTransactionById(command.parentTransactionId);
    if (parent == null) {
      return const Result.failure(
        Failure(
          code: 'refund_parent_not_found',
          message: 'Original expense not found.',
        ),
      );
    }
    if (parent.businessPurpose != BusinessPurpose.dailyExpense &&
        parent.businessPurpose != BusinessPurpose.reimbursementAdvance) {
      return const Result.failure(
        Failure(
          code: 'refund_parent_not_expense',
          message: 'Refund can only be applied to an expense transaction.',
        ),
      );
    }
    if (parent.businessPurpose == BusinessPurpose.reimbursementAdvance) {
      final summary = await query.getReimbursementSummary(
        parent.rootTransactionId,
      );
      if (summary?.isClosed ?? false) {
        return const Result.failure(
          Failure(
            code: 'refund_parent_reimbursement_closed',
            message: 'Refund is not supported after reimbursement is closed.',
          ),
        );
      }
    }
    if (parent.businessState != BusinessState.current) {
      return const Result.failure(
        Failure(
          code: 'refund_parent_not_current',
          message: 'Refund can only be applied to a current expense.',
        ),
      );
    }
    if (parent.currencyCode != command.amount.currency) {
      return const Result.failure(
        Failure(
          code: 'refund_currency_mismatch',
          message: 'Refund currency must match the original expense.',
        ),
      );
    }

    final refunded = await query.getRefundedTotal(
      parent.rootTransactionId,
      currencyCode: parent.currencyCode,
    );
    final remaining = parent.primaryAmount - refunded;
    if (command.amount.minorUnits > remaining.minorUnits) {
      return Result.failure(
        Failure(
          code: 'refund_exceeds_remaining',
          message:
              'Refund exceeds remaining refundable amount '
              '(${remaining.format(withCurrency: true)}).',
        ),
      );
    }

    final refundCreditAccountId =
        await _findRefundCreditAccountIdInParentEntries(
          parentId: parent.id,
          parentPurpose: parent.businessPurpose,
        );
    if (refundCreditAccountId == null) {
      return const Result.failure(
        Failure(
          code: 'refund_expense_account_not_found',
          message: 'Original refund target account cannot be located.',
        ),
      );
    }

    final roleFailure = await _validateAccountUsages({
      command.refundToAccountId: AccountUsage.settlement,
    });
    if (roleFailure != null) {
      return Result.failure(roleFailure);
    }

    return _post(
      PostTransactionCommand(
        businessPurpose: BusinessPurpose.refund,
        occurredAt: command.occurredAt,
        currencyCode: command.amount.currency,
        primaryAmount: command.amount,
        counterpartyName: command.counterpartyName,
        note: command.note,
        rootTransactionId: parent.rootTransactionId,
        parentTransactionId: parent.id,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
        details: [
          PostTransactionDetailInput(
            lineNo: 1,
            type: TransactionDetailType.refundMain,
            amount: command.amount,
          ),
        ],
        entries: [
          PostEntryInput(
            accountId: command.refundToAccountId,
            direction: EntryDirection.debit,
            amount: command.amount,
          ),
          PostEntryInput(
            accountId: refundCreditAccountId,
            direction: EntryDirection.credit,
            amount: command.amount,
          ),
        ],
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> createReimbursementAdvance(
    CreateReimbursementAdvanceCommand command,
  ) async {
    if (command.amount.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_amount_not_positive',
          message: 'Advance amount must be positive.',
        ),
      );
    }
    final roleFailure = await _validateAccountConstraints(
      usages: {
        command.receivableAccountId: AccountUsage.reimbursement,
        command.paidFromAccountId: AccountUsage.settlement,
      },
      types: {
        command.expenseCategoryId: {AccountType.expense},
      },
    );
    if (roleFailure != null) {
      return Result.failure(roleFailure);
    }

    return _post(
      PostTransactionCommand(
        businessPurpose: BusinessPurpose.reimbursementAdvance,
        occurredAt: command.occurredAt,
        currencyCode: command.amount.currency,
        primaryAmount: command.amount,
        counterpartyName: command.counterpartyName,
        note: command.note,
        reimbursementExpenseAccountId: command.expenseCategoryId,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
        details: [
          PostTransactionDetailInput(
            lineNo: 1,
            type: TransactionDetailType.reimbursementAdvanceMain,
            amount: command.amount,
          ),
        ],
        entries: [
          PostEntryInput(
            accountId: command.receivableAccountId,
            direction: EntryDirection.debit,
            amount: command.amount,
          ),
          PostEntryInput(
            accountId: command.paidFromAccountId,
            direction: EntryDirection.credit,
            amount: command.amount,
          ),
        ],
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> createReimbursementReceipt(
    CreateReimbursementReceiptCommand command,
  ) async {
    if (command.amount.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_amount_not_positive',
          message: 'Receipt amount must be positive.',
        ),
      );
    }
    final query = _queryRepository;
    final advance = await query.findTransactionById(
      command.advanceTransactionId,
    );
    final advanceFailure = _validateAdvance(advance, command.amount.currency);
    if (advanceFailure != null) {
      return Result.failure(advanceFailure);
    }
    final summary = await query.getReimbursementSummary(advance!.id);
    if (summary == null) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_summary_unavailable',
          message: 'Cannot resolve reimbursement state.',
        ),
      );
    }
    if (summary.isClosed) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_already_closed',
          message: 'This reimbursement chain is already closed.',
        ),
      );
    }
    if (command.amount.minorUnits > summary.outstanding.minorUnits) {
      return Result.failure(
        Failure(
          code: 'reimbursement_receipt_exceeds_outstanding',
          message:
              'Receipt exceeds outstanding receivable '
              '(${summary.outstanding.format(withCurrency: true)}).',
        ),
      );
    }

    final roleFailure = await _validateAccountUsages({
      command.receiveAccountId: AccountUsage.settlement,
    });
    if (roleFailure != null) {
      return Result.failure(roleFailure);
    }

    return _post(
      PostTransactionCommand(
        businessPurpose: BusinessPurpose.reimbursementReceipt,
        occurredAt: command.occurredAt,
        currencyCode: command.amount.currency,
        primaryAmount: command.amount,
        counterpartyName: command.counterpartyName,
        note: command.note,
        rootTransactionId: advance.rootTransactionId,
        parentTransactionId: advance.id,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
        details: [
          PostTransactionDetailInput(
            lineNo: 1,
            type: TransactionDetailType.reimbursementReceiptMain,
            amount: command.amount,
          ),
        ],
        entries: [
          PostEntryInput(
            accountId: command.receiveAccountId,
            direction: EntryDirection.debit,
            amount: command.amount,
          ),
          PostEntryInput(
            accountId: command.receivableAccountId,
            direction: EntryDirection.credit,
            amount: command.amount,
          ),
        ],
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> closeReimbursement(
    CloseReimbursementCommand command,
  ) async {
    if (command.actualReceivedAmount.minorUnits < 0) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_close_amount_negative',
          message: 'Final receipt amount cannot be negative.',
        ),
      );
    }
    final query = _queryRepository;
    final resolver = _systemAccounts;
    final advance = await query.findTransactionById(
      command.advanceTransactionId,
    );
    final advanceFailure = _validateAdvance(
      advance,
      command.actualReceivedAmount.currency,
    );
    if (advanceFailure != null) {
      return Result.failure(advanceFailure);
    }
    final summary = await query.getReimbursementSummary(advance!.id);
    if (summary == null || summary.isClosed) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_already_closed',
          message: 'This reimbursement chain is already closed.',
        ),
      );
    }

    final outstanding = summary.outstanding;
    final actual = command.actualReceivedAmount;
    final gap = actual - outstanding;
    final hasOverGap = gap.minorUnits > 0;
    final hasUnderGap = gap.minorUnits < 0;

    final details = <PostTransactionDetailInput>[
      PostTransactionDetailInput(
        lineNo: 1,
        type: TransactionDetailType.reimbursementCloseMain,
        amount: outstanding,
      ),
      if (hasOverGap)
        PostTransactionDetailInput(
          lineNo: 2,
          type: TransactionDetailType.reimbursementGapIncome,
          amount: gap,
        ),
      if (hasUnderGap)
        PostTransactionDetailInput(
          lineNo: 2,
          type: TransactionDetailType.reimbursementGapExpense,
          amount: gap.abs(),
        ),
    ];

    final entries = <PostEntryInput>[
      if (actual.minorUnits > 0)
        PostEntryInput(
          accountId: command.receiveAccountId,
          direction: EntryDirection.debit,
          amount: actual,
        ),
      PostEntryInput(
        accountId: command.receivableAccountId,
        direction: EntryDirection.credit,
        amount: outstanding,
      ),
    ];

    if (hasOverGap) {
      final gapAccountId = await resolver.resolveReimbursementGapIncome(
        currencyCode: actual.currency,
      );
      entries.add(
        PostEntryInput(
          accountId: gapAccountId,
          direction: EntryDirection.credit,
          amount: gap,
        ),
      );
    } else if (hasUnderGap) {
      final originalExpenseId = advance.reimbursementExpenseAccountId;
      if (originalExpenseId == null) {
        return const Result.failure(
          Failure(
            code: 'reimbursement_close_expense_missing',
            message: 'Original reimbursement expense category is not recorded.',
          ),
        );
      }
      entries.add(
        PostEntryInput(
          accountId: originalExpenseId,
          direction: EntryDirection.debit,
          amount: gap.abs(),
        ),
      );
    }

    final roleFailure = await _validateAccountUsages({
      if (actual.minorUnits > 0)
        command.receiveAccountId: AccountUsage.settlement,
    });
    if (roleFailure != null) {
      return Result.failure(roleFailure);
    }

    return _post(
      PostTransactionCommand(
        businessPurpose: BusinessPurpose.reimbursementClose,
        occurredAt: command.occurredAt,
        currencyCode: actual.currency,
        primaryAmount: actual.minorUnits > 0 ? actual : outstanding,
        counterpartyName: command.counterpartyName,
        note: command.note,
        rootTransactionId: advance.rootTransactionId,
        parentTransactionId: advance.id,
        reimbursementExpenseAccountId: advance.reimbursementExpenseAccountId,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
        details: details,
        entries: entries,
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> createRepayment(
    CreateRepaymentCommand command,
  ) async {
    final principal = command.principal;
    final interest = command.interest;
    final fee = command.fee;
    final discount = command.discount;
    if (principal.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'repayment_principal_not_positive',
          message: 'Repayment principal must be positive.',
        ),
      );
    }
    if (interest != null && interest.currency != principal.currency) {
      return const Result.failure(
        Failure(
          code: 'repayment_currency_mismatch',
          message: 'Repayment interest currency mismatch.',
        ),
      );
    }
    if (fee != null && fee.currency != principal.currency) {
      return const Result.failure(
        Failure(
          code: 'repayment_currency_mismatch',
          message: 'Repayment fee currency mismatch.',
        ),
      );
    }
    if (discount != null && discount.currency != principal.currency) {
      return const Result.failure(
        Failure(
          code: 'repayment_currency_mismatch',
          message: 'Repayment discount currency mismatch.',
        ),
      );
    }
    if (fee != null &&
        fee.minorUnits > 0 &&
        command.feeExpenseAccountId == null) {
      return const Result.failure(
        Failure(
          code: 'repayment_fee_account_required',
          message: 'Fee category is required when fee is positive.',
        ),
      );
    }

    final hasInterest = interest != null && interest.minorUnits > 0;
    final hasFee = fee != null && fee.minorUnits > 0;
    final hasDiscount = discount != null && discount.minorUnits > 0;
    final totalPaid =
        principal +
        (hasInterest ? interest : Money.zero(currency: principal.currency)) +
        (hasFee ? fee : Money.zero(currency: principal.currency)) -
        (hasDiscount ? discount : Money.zero(currency: principal.currency));
    if (totalPaid.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'repayment_total_paid_not_positive',
          message: 'Repayment total paid must be positive.',
        ),
      );
    }

    final interestExpenseAccountId =
        hasInterest && command.interestExpenseAccountId == null
            ? await _systemAccounts.resolveDebtInterestExpense(
              currencyCode: principal.currency,
            )
            : command.interestExpenseAccountId;
    final discountIncomeAccountId =
        hasDiscount
            ? await _systemAccounts.resolveDiscountIncome(
              currencyCode: principal.currency,
            )
            : null;

    final roleFailure = await _validateAccountConstraints(
      usages: {
        command.liabilityAccountId: AccountUsage.repaymentTarget,
        command.paidFromAccountId: AccountUsage.repaymentSource,
      },
      types: {
        if (hasInterest) interestExpenseAccountId!: {AccountType.expense},
        if (hasFee) command.feeExpenseAccountId!: {AccountType.expense},
        if (hasDiscount) discountIncomeAccountId!: {AccountType.income},
      },
    );
    if (roleFailure != null) {
      return Result.failure(roleFailure);
    }

    final details = <PostTransactionDetailInput>[
      PostTransactionDetailInput(
        lineNo: 1,
        type: TransactionDetailType.repaymentPrincipal,
        amount: principal,
      ),
      if (hasInterest)
        PostTransactionDetailInput(
          lineNo: 2,
          type: TransactionDetailType.repaymentInterest,
          amount: interest,
        ),
      if (hasFee)
        PostTransactionDetailInput(
          lineNo: hasInterest ? 3 : 2,
          type: TransactionDetailType.repaymentFee,
          amount: fee,
        ),
      if (hasDiscount)
        PostTransactionDetailInput(
          lineNo: 2 + (hasInterest ? 1 : 0) + (hasFee ? 1 : 0),
          type: TransactionDetailType.repaymentDiscount,
          amount: discount,
        ),
    ];

    final entries = <PostEntryInput>[
      PostEntryInput(
        accountId: command.liabilityAccountId,
        direction: EntryDirection.debit,
        amount: principal,
      ),
      if (hasInterest)
        PostEntryInput(
          accountId: interestExpenseAccountId!,
          direction: EntryDirection.debit,
          amount: interest,
        ),
      if (hasFee)
        PostEntryInput(
          accountId: command.feeExpenseAccountId!,
          direction: EntryDirection.debit,
          amount: fee,
        ),
      if (hasDiscount)
        PostEntryInput(
          accountId: discountIncomeAccountId!,
          direction: EntryDirection.credit,
          amount: discount,
        ),
      PostEntryInput(
        accountId: command.paidFromAccountId,
        direction: EntryDirection.credit,
        amount: totalPaid,
      ),
    ];

    return _post(
      PostTransactionCommand(
        businessPurpose: BusinessPurpose.debtRepayment,
        occurredAt: command.occurredAt,
        currencyCode: principal.currency,
        primaryAmount: totalPaid,
        counterpartyName: command.counterpartyName,
        note: command.note,
        ownership: command.ownership,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
        details: details,
        entries: entries,
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> createBorrowing(
    CreateBorrowingCommand command,
  ) async {
    if (command.amount.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'borrowing_amount_not_positive',
          message: 'Borrowing amount must be positive.',
        ),
      );
    }

    final receiveAccountId = command.receiveAccountId;
    final useSystemEquity = receiveAccountId == null;
    final roleFailure = await _validateAccountUsages({
      command.liabilityAccountId: AccountUsage.borrowingLiability,
      if (!useSystemEquity) receiveAccountId: AccountUsage.fund,
    });
    if (roleFailure != null) {
      return Result.failure(roleFailure);
    }

    final debitAccountId =
        useSystemEquity
            ? await _systemAccounts.resolveOpeningBalance(
              currencyCode: command.amount.currency,
            )
            : receiveAccountId;

    return _post(
      PostTransactionCommand(
        businessPurpose: BusinessPurpose.borrowing,
        occurredAt: command.occurredAt,
        currencyCode: command.amount.currency,
        primaryAmount: command.amount,
        counterpartyName: command.counterpartyName,
        note: command.note,
        ownership: command.ownership,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
        details: [
          PostTransactionDetailInput(
            lineNo: 1,
            type: TransactionDetailType.borrowingPrincipal,
            amount: command.amount,
          ),
        ],
        entries: [
          PostEntryInput(
            accountId: debitAccountId,
            direction: EntryDirection.debit,
            amount: command.amount,
          ),
          PostEntryInput(
            accountId: command.liabilityAccountId,
            direction: EntryDirection.credit,
            amount: command.amount,
          ),
        ],
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> createOpeningBalance(
    CreateOpeningBalanceCommand command,
  ) async {
    final repository = _accountRepository;
    final account = await repository.findAccountById(command.accountId);
    if (account == null) {
      return const Result.failure(
        Failure(code: 'account_not_found', message: 'Account does not exist.'),
      );
    }
    if (account.archivedAt != null) {
      return const Result.failure(
        Failure(
          code: 'account_archived',
          message: 'Cannot initialize archived account.',
        ),
      );
    }
    if (account.currencyCode != command.amount.currency) {
      return const Result.failure(
        Failure(
          code: 'opening_balance_currency_mismatch',
          message: 'Opening balance currency must match account currency.',
        ),
      );
    }
    if (command.amount.minorUnits == 0) {
      return const Result.failure(
        Failure(
          code: 'opening_balance_zero',
          message: 'Opening balance amount cannot be zero.',
        ),
      );
    }

    final amount = command.amount.abs();
    final accountDirection = _directionForBalanceDelta(
      accountType: account.type,
      deltaMinor: command.amount.minorUnits,
    );
    final equityDirection =
        accountDirection == EntryDirection.debit
            ? EntryDirection.credit
            : EntryDirection.debit;

    final equityAccountId = await _systemAccounts
        .resolveOpeningBalance(currencyCode: amount.currency);

    return _post(
      PostTransactionCommand(
        businessPurpose: BusinessPurpose.openingBalance,
        occurredAt: command.occurredAt,
        currencyCode: amount.currency,
        primaryAmount: amount,
        counterpartyName: command.counterpartyName,
        note: command.note,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
        details: [
          PostTransactionDetailInput(
            lineNo: 1,
            type: TransactionDetailType.openingBalanceMain,
            amount: amount,
          ),
        ],
        entries: [
          PostEntryInput(
            accountId: command.accountId,
            direction: accountDirection,
            amount: amount,
          ),
          PostEntryInput(
            accountId: equityAccountId,
            direction: equityDirection,
            amount: amount,
          ),
        ],
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> adjustBalance(
    AdjustBalanceCommand command,
  ) async {
    final repository = _accountRepository;
    final account = await repository.findAccountById(command.accountId);
    if (account == null) {
      return const Result.failure(
        Failure(code: 'account_not_found', message: 'Account does not exist.'),
      );
    }
    if (account.archivedAt != null) {
      return const Result.failure(
        Failure(
          code: 'account_archived',
          message: 'Cannot adjust archived account.',
        ),
      );
    }
    if (account.type != AccountType.asset &&
        account.type != AccountType.liability) {
      return const Result.failure(
        Failure(
          code: 'account_not_adjustable',
          message:
              'Only asset and liability accounts support balance adjustment.',
        ),
      );
    }
    if (account.currencyCode != command.targetBalance.currency) {
      return const Result.failure(
        Failure(
          code: 'balance_adjustment_currency_mismatch',
          message: 'Target balance currency must match account currency.',
        ),
      );
    }

    final deltaMinor =
        command.targetBalance.minorUnits - account.balance.minorUnits;
    if (deltaMinor == 0) {
      return const Result.failure(
        Failure(
          code: 'balance_adjustment_zero_delta',
          message: 'Balance is already at the target value.',
        ),
      );
    }

    final amount = Money(
      minorUnits: deltaMinor.abs(),
      currency: command.targetBalance.currency,
    );
    final accountDirection = _directionForBalanceDelta(
      accountType: account.type,
      deltaMinor: deltaMinor,
    );
    final equityDirection =
        accountDirection == EntryDirection.debit
            ? EntryDirection.credit
            : EntryDirection.debit;

    final equityAccountId = await _systemAccounts
        .resolveOpeningBalance(currencyCode: amount.currency);

    return _post(
      PostTransactionCommand(
        businessPurpose: BusinessPurpose.balanceAdjustment,
        occurredAt: command.occurredAt,
        currencyCode: amount.currency,
        primaryAmount: amount,
        counterpartyName: command.counterpartyName,
        note: command.note,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
        details: [
          PostTransactionDetailInput(
            lineNo: 1,
            type: TransactionDetailType.balanceAdjustmentMain,
            amount: amount,
          ),
        ],
        entries: [
          PostEntryInput(
            accountId: command.accountId,
            direction: accountDirection,
            amount: amount,
          ),
          PostEntryInput(
            accountId: equityAccountId,
            direction: equityDirection,
            amount: amount,
          ),
        ],
      ),
    );
  }

  EntryDirection _directionForBalanceDelta({
    required AccountType accountType,
    required int deltaMinor,
  }) {
    final increasesOnDebit =
        accountType == AccountType.asset || accountType == AccountType.expense;
    final increase = deltaMinor > 0;

    if (increasesOnDebit) {
      return increase ? EntryDirection.debit : EntryDirection.credit;
    }

    return increase ? EntryDirection.credit : EntryDirection.debit;
  }

  Failure? _validateTransferFee(CreateTransferCommand command) {
    final feeAmount = command.feeAmount;
    final feeExpenseAccountId = command.feeExpenseAccountId;
    if (feeAmount == null) {
      return feeExpenseAccountId == null
          ? null
          : const Failure(
            code: 'transfer_fee_amount_required',
            message: 'Transfer fee amount is required when fee account is set.',
          );
    }

    if (feeAmount.currency != command.amount.currency) {
      return const Failure(
        code: 'transfer_fee_currency_mismatch',
        message: 'Transfer fee currency must match transfer amount currency.',
      );
    }
    if (feeAmount.minorUnits < 0) {
      return const Failure(
        code: 'transfer_fee_negative',
        message: 'Transfer fee cannot be negative.',
      );
    }
    if (feeAmount.minorUnits == 0) {
      return feeExpenseAccountId == null
          ? null
          : const Failure(
            code: 'transfer_fee_positive_required',
            message: 'Transfer fee must be positive when fee account is set.',
          );
    }
    if (feeExpenseAccountId == null) {
      return const Failure(
        code: 'transfer_fee_account_required',
        message:
            'Transfer fee account is required when fee amount is positive.',
      );
    }

    return null;
  }

  @override
  Future<Result<CreatedTransactionResult>> correctExpense(
    CorrectExpenseCommand command,
  ) {
    return _correctTransaction(
      _CorrectTransactionDraft(
        transactionId: command.transactionId,
        businessPurpose: BusinessPurpose.dailyExpense,
        amount: command.amount,
        paidFromAccountId: command.paidFromAccountId,
        expenseAccountId: command.expenseAccountId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctIncome(
    CorrectIncomeCommand command,
  ) {
    return _correctTransaction(
      _CorrectTransactionDraft(
        transactionId: command.transactionId,
        businessPurpose: BusinessPurpose.dailyIncome,
        amount: command.amount,
        receiveAccountId: command.receiveAccountId,
        incomeAccountId: command.incomeAccountId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctTransfer(
    CorrectTransferCommand command,
  ) {
    return _correctTransaction(
      _CorrectTransactionDraft(
        transactionId: command.transactionId,
        businessPurpose: BusinessPurpose.transfer,
        amount: command.amount,
        fromAccountId: command.fromAccountId,
        toAccountId: command.toAccountId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctReimbursementAdvance(
    CorrectReimbursementAdvanceCommand command,
  ) {
    return _correctTransaction(
      _CorrectTransactionDraft(
        transactionId: command.transactionId,
        businessPurpose: BusinessPurpose.reimbursementAdvance,
        amount: command.amount,
        paidFromAccountId: command.paidFromAccountId,
        expenseAccountId: command.expenseCategoryId,
        receivableAccountId: command.receivableAccountId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctRefund(
    CorrectRefundCommand command,
  ) {
    return _correctTransaction(
      _CorrectTransactionDraft(
        transactionId: command.transactionId,
        businessPurpose: BusinessPurpose.refund,
        amount: command.amount,
        receiveAccountId: command.refundToAccountId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctReimbursementReceipt(
    CorrectReimbursementReceiptCommand command,
  ) {
    return _correctTransaction(
      _CorrectTransactionDraft(
        transactionId: command.transactionId,
        businessPurpose: BusinessPurpose.reimbursementReceipt,
        amount: command.amount,
        receivableAccountId: command.receivableAccountId,
        receiveAccountId: command.receiveAccountId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctReimbursementClose(
    CorrectReimbursementCloseCommand command,
  ) {
    return _correctTransaction(
      _CorrectTransactionDraft(
        transactionId: command.transactionId,
        businessPurpose: BusinessPurpose.reimbursementClose,
        amount: command.actualReceivedAmount,
        receivableAccountId: command.receivableAccountId,
        receiveAccountId: command.receiveAccountId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctBorrowing(
    CorrectBorrowingCommand command,
  ) {
    return _correctTransaction(
      _CorrectTransactionDraft(
        transactionId: command.transactionId,
        businessPurpose: BusinessPurpose.borrowing,
        amount: command.amount,
        liabilityAccountId: command.liabilityAccountId,
        receiveAccountId: command.receiveAccountId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctRepayment(
    CorrectRepaymentCommand command,
  ) {
    return _correctTransaction(
      _CorrectTransactionDraft(
        transactionId: command.transactionId,
        businessPurpose: BusinessPurpose.debtRepayment,
        amount: command.principal,
        repaymentInterest: command.interest,
        repaymentFee: command.fee,
        repaymentDiscount: command.discount,
        liabilityAccountId: command.liabilityAccountId,
        paidFromAccountId: command.paidFromAccountId,
        interestExpenseAccountId: command.interestExpenseAccountId,
        feeExpenseAccountId: command.feeExpenseAccountId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
      ),
    );
  }

  Future<Result<CreatedTransactionResult>> _correctTransaction(
    _CorrectTransactionDraft command,
  ) async {
    final query = _queryRepository;
    final original =
        await query.watchTransactionDetail(command.transactionId).first;
    if (original == null) {
      return const Result.failure(
        Failure(
          code: 'transaction_not_found',
          message: 'Transaction not found.',
        ),
      );
    }
    if (original.transaction.businessState != BusinessState.current) {
      return const Result.failure(
        Failure(
          code: 'transaction_not_current',
          message: 'Only current transactions can be corrected.',
        ),
      );
    }
    if (!_supportsFormCorrection(original.transaction.businessPurpose)) {
      return const Result.failure(
        Failure(
          code: 'transaction_correction_unsupported',
          message: 'This transaction type cannot be edited in this form.',
        ),
      );
    }
    if (original.transaction.businessPurpose != command.businessPurpose) {
      return const Result.failure(
        Failure(
          code: 'transaction_correction_purpose_mismatch',
          message: 'Correction command purpose must match the transaction.',
        ),
      );
    }

    if (original.children.isNotEmpty) {
      final structure = _replacementStructure(command);
      if (!_matchesOriginalStructure(original, structure)) {
        return const Result.failure(
          Failure(
            code: 'transaction_has_children',
            message:
                'Transactions with child records can only update metadata.',
          ),
        );
      }
      final metadata = await updateTransactionMetadata(
        UpdateTransactionMetadataCommand(
          transactionId: command.transactionId,
          note:
              command.note == null
                  ? const Patch<String>.clear()
                  : Patch.set(command.note!),
          isExcludedFromStats: command.isExcludedFromStats,
          isExcludedFromBudget: command.isExcludedFromBudget,
        ),
      );
      return metadata.when(
        success:
            (_) => Result.success(
              CreatedTransactionResult(
                transactionId: original.transaction.id,
                rootTransactionId: original.transaction.rootTransactionId,
              ),
            ),
        failure: Result.failure,
      );
    }

    final replacement = await _buildReplacementCommand(command, original);
    switch (replacement) {
      case FailureResult(:final failure):
        return Result.failure(failure);
      case Success(:final value):
        final reversal = _buildReversalCommand(
          original,
          reason: MutationReason.correction,
        );
        final result = await _postMutation(
          stateUpdates: [
            TransactionStateUpdate(
              transactionId: original.transaction.id,
              businessState: BusinessState.replaced,
            ),
          ],
          commands: [reversal, value],
        );
        return result.when(
          success: (results) => Result.success(results.last),
          failure: Result.failure,
        );
    }
  }

  @override
  Future<Result<void>> deleteTransaction(
    DeleteTransactionCommand command,
  ) async {
    final query = _queryRepository;
    final target =
        await query.watchTransactionDetail(command.transactionId).first;
    if (target == null) {
      return const Result.failure(
        Failure(
          code: 'transaction_not_found',
          message: 'Transaction not found.',
        ),
      );
    }
    if (target.transaction.businessState != BusinessState.current) {
      return const Result.failure(
        Failure(
          code: 'transaction_not_current',
          message: 'Only current transactions can be deleted.',
        ),
      );
    }

    final detailsToCancel = <TransactionDetailView>[];
    for (final child in target.children) {
      final childDetail = await query.watchTransactionDetail(child.id).first;
      if (childDetail != null &&
          childDetail.transaction.businessState == BusinessState.current) {
        detailsToCancel.add(childDetail);
      }
    }
    detailsToCancel.add(target);

    final result = await _postMutation(
      stateUpdates: [
        for (final detail in detailsToCancel)
          TransactionStateUpdate(
            transactionId: detail.transaction.id,
            businessState: BusinessState.canceled,
          ),
      ],
      commands: [
        for (final detail in detailsToCancel)
          _buildReversalCommand(detail, reason: MutationReason.delete),
      ],
    );
    return result.when(
      success: (_) => const Result.success(null),
      failure: Result.failure,
    );
  }

  @override
  Future<Result<void>> updateTransactionMetadata(
    UpdateTransactionMetadataCommand command,
  ) async {
    if (command.note == null &&
        command.isExcludedFromStats == null &&
        command.isExcludedFromBudget == null) {
      return const Result.success(null);
    }
    final repository = _postingRepository;
    final transaction = await _queryRepository.findTransactionById(
      command.transactionId,
    );
    if (transaction == null) {
      return const Result.failure(
        Failure(
          code: 'transaction_not_found',
          message: 'Transaction does not exist.',
        ),
      );
    }
    try {
      await repository.updateTransactionMetadata(
        transactionId: command.transactionId,
        note: command.note,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
      );
      return const Result.success(null);
    } on Object catch (error) {
      return Result.failure(
        Failure(
          code: 'transaction_metadata_update_failed',
          message: 'Failed to update transaction metadata.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<void>> updateTransactionBasics(
    UpdateTransactionBasicsCommand command,
  ) async {
    if (command.occurredAt == null &&
        command.settlementAccountId == null &&
        command.reimbursementAccountId == null) {
      return const Result.success(null);
    }
    final repository = _postingRepository;

    final query = _queryRepository;
    final detail =
        await query.watchTransactionDetail(command.transactionId).first;
    if (detail == null) {
      return const Result.failure(
        Failure(
          code: 'transaction_not_found',
          message: 'Transaction not found.',
        ),
      );
    }
    if (detail.transaction.businessState != BusinessState.current) {
      return const Result.failure(
        Failure(
          code: 'transaction_not_current',
          message: 'Only current transactions can be updated.',
        ),
      );
    }

    final reassignments = <EntryAccountReassignment>[];
    final settlementAccountId = command.settlementAccountId;
    if (settlementAccountId != null) {
      final entry = _settlementEntry(detail);
      if (entry == null) {
        return const Result.failure(
          Failure(
            code: 'settlement_account_not_found',
            message: 'Settlement account cannot be located.',
          ),
        );
      }
      final failure = await _validateDirectAccount(
        settlementAccountId,
        currencyCode: detail.transaction.currencyCode,
        expectedTypes: {AccountType.asset, AccountType.liability},
        requiredUsage: AccountUsage.settlement,
        allowReimbursementSubtype: false,
      );
      if (failure != null) {
        return Result.failure(failure);
      }
      if (entry.accountId != settlementAccountId) {
        reassignments.add(
          EntryAccountReassignment(
            transactionId: detail.transaction.id,
            fromAccountId: entry.accountId,
            toAccountId: settlementAccountId,
          ),
        );
      }
    }

    final reimbursementAccountId = command.reimbursementAccountId;
    if (reimbursementAccountId != null) {
      if (detail.transaction.businessPurpose !=
          BusinessPurpose.reimbursementAdvance) {
        return const Result.failure(
          Failure(
            code: 'reimbursement_account_unsupported',
            message:
                'Only reimbursement advances can change reimbursement account.',
          ),
        );
      }
      final entry = _reimbursementReceivableEntry(detail);
      if (entry == null) {
        return const Result.failure(
          Failure(
            code: 'reimbursement_account_not_found',
            message: 'Reimbursement account cannot be located.',
          ),
        );
      }
      final failure = await _validateDirectAccount(
        reimbursementAccountId,
        currencyCode: detail.transaction.currencyCode,
        expectedTypes: {AccountType.asset},
        requiredSubtype: AccountSubtype.reimbursement,
      );
      if (failure != null) {
        return Result.failure(failure);
      }
      if (entry.accountId != reimbursementAccountId) {
        reassignments.add(
          EntryAccountReassignment(
            rootTransactionId: detail.transaction.rootTransactionId,
            fromAccountId: entry.accountId,
            toAccountId: reimbursementAccountId,
          ),
        );
      }
    }

    try {
      await repository.updateTransactionBasics(
        transactionId: command.transactionId,
        occurredAt: command.occurredAt,
        entryAccountReassignments: reassignments,
      );
      return const Result.success(null);
    } on Object catch (error) {
      return Result.failure(
        Failure(
          code: 'transaction_basics_update_failed',
          message: 'Failed to update transaction basics.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<void>> updateTransactionOwnership(
    UpdateTransactionOwnershipCommand command,
  ) async {
    final repository = _postingRepository;
    final transaction = await _queryRepository.findTransactionById(
      command.transactionId,
    );
    if (transaction == null) {
      return const Result.failure(
        Failure(
          code: 'transaction_not_found',
          message: 'Transaction does not exist.',
        ),
      );
    }
    try {
      await repository.updateTransactionOwnership(
        transactionId: command.transactionId,
        ownership: command.ownership,
      );
      return const Result.success(null);
    } on Object catch (error) {
      return Result.failure(
        Failure(
          code: 'transaction_ownership_update_failed',
          message: 'Failed to update transaction ownership.',
          cause: error,
        ),
      );
    }
  }

  EntryLineView? _settlementEntry(TransactionDetailView detail) {
    final direction = switch (detail.transaction.businessPurpose) {
      BusinessPurpose.dailyExpense ||
      BusinessPurpose.reimbursementAdvance ||
      BusinessPurpose.debtRepayment => EntryDirection.credit,
      BusinessPurpose.dailyIncome ||
      BusinessPurpose.refund ||
      BusinessPurpose.reimbursementReceipt ||
      BusinessPurpose.reimbursementClose ||
      BusinessPurpose.borrowing => EntryDirection.debit,
      _ => null,
    };
    if (direction == null) return null;
    for (final entry in detail.entries) {
      final settlementType =
          entry.accountType == AccountType.asset ||
          entry.accountType == AccountType.liability;
      final isReimbursementReceivable =
          detail.transaction.businessPurpose ==
              BusinessPurpose.reimbursementAdvance &&
          entry.direction == EntryDirection.debit &&
          entry.accountType == AccountType.asset;
      if (settlementType &&
          !isReimbursementReceivable &&
          entry.direction == direction) {
        return entry;
      }
    }
    return null;
  }

  EntryLineView? _reimbursementReceivableEntry(TransactionDetailView detail) {
    for (final entry in detail.entries) {
      if (entry.accountType == AccountType.asset &&
          entry.direction == EntryDirection.debit) {
        return entry;
      }
    }
    return null;
  }

  Future<Failure?> _validateDirectAccount(
    int accountId, {
    required String currencyCode,
    required Set<AccountType> expectedTypes,
    AccountSubtype? requiredSubtype,
    AccountUsage? requiredUsage,
    bool allowReimbursementSubtype = true,
  }) async {
    final repository = _accountRepository;
    final account = await repository.findAccountById(accountId);
    if (account == null) {
      return Failure(
        code: 'account_not_found',
        message: 'Account $accountId does not exist.',
      );
    }
    if (account.archivedAt != null) {
      return Failure(
        code: 'account_archived',
        message: 'Account $accountId is archived.',
      );
    }
    if (account.currencyCode != currencyCode) {
      return Failure(
        code: 'account_currency_mismatch',
        message: 'Account $accountId cannot be used for this currency.',
      );
    }
    if (!expectedTypes.contains(account.type)) {
      return Failure(
        code: 'account_role_invalid',
        message: 'Account $accountId cannot be used for this transaction.',
      );
    }
    if (requiredSubtype != null && account.subtype != requiredSubtype) {
      return Failure(
        code: 'account_subtype_invalid',
        message: 'Account $accountId cannot be used for this transaction.',
      );
    }
    if (requiredUsage != null && !accountMatchesUsage(account, requiredUsage)) {
      return Failure(
        code: 'account_role_invalid',
        message: 'Account $accountId cannot be used for this transaction.',
      );
    }
    if (!allowReimbursementSubtype &&
        account.subtype == AccountSubtype.reimbursement) {
      return Failure(
        code: 'account_subtype_invalid',
        message: 'Reimbursement account cannot be used as settlement account.',
      );
    }
    return null;
  }

  bool _supportsFormCorrection(BusinessPurpose purpose) {
    return switch (purpose) {
      BusinessPurpose.dailyExpense ||
      BusinessPurpose.dailyIncome ||
      BusinessPurpose.transfer ||
      BusinessPurpose.reimbursementAdvance ||
      BusinessPurpose.refund ||
      BusinessPurpose.reimbursementReceipt ||
      BusinessPurpose.reimbursementClose ||
      BusinessPurpose.debtRepayment ||
      BusinessPurpose.borrowing => true,
      _ => false,
    };
  }

  PostTransactionCommand _buildReversalCommand(
    TransactionDetailView detail, {
    required MutationReason reason,
  }) {
    final transaction = detail.transaction;
    return PostTransactionCommand(
      businessPurpose: transaction.businessPurpose,
      occurredAt: DateTime.now(),
      currencyCode: transaction.currencyCode,
      primaryAmount: -transaction.primaryAmount,
      counterpartyName: transaction.counterpartyName,
      note: transaction.note,
      rootTransactionId: transaction.rootTransactionId,
      parentTransactionId: transaction.parentTransactionId,
      reimbursementExpenseAccountId: transaction.reimbursementExpenseAccountId,
      mutationKind: MutationKind.reversal,
      mutationPreviousTransactionId: transaction.id,
      mutationReason: reason,
      businessState: BusinessState.compensation,
      isExcludedFromStats: transaction.isExcludedFromStats,
      isExcludedFromBudget: transaction.isExcludedFromBudget,
      sourceKind: transaction.sourceKind,
      ownership: transaction.ownership,
      details: [
        for (final line in detail.details)
          PostTransactionDetailInput(
            lineNo: line.lineNo,
            type: line.type,
            amount: -line.amount,
          ),
      ],
      entries: [
        for (final entry in detail.entries)
          PostEntryInput(
            accountId: entry.accountId,
            direction: entry.direction,
            amount: -entry.amount,
          ),
      ],
    );
  }

  Future<Result<PostTransactionCommand>> _buildReplacementCommand(
    _CorrectTransactionDraft command,
    TransactionDetailView original,
  ) async {
    final base = _replacementStructure(command);
    final roleFailure = await _validateReplacementRoles(base);
    if (roleFailure != null) {
      return Result.failure(roleFailure);
    }

    if (command.businessPurpose == BusinessPurpose.debtRepayment) {
      return _buildRepaymentReplacementCommand(command, original);
    }
    if (command.businessPurpose == BusinessPurpose.refund) {
      return _buildRefundReplacementCommand(command, original);
    }
    if (command.businessPurpose == BusinessPurpose.reimbursementReceipt) {
      return _buildReimbursementReceiptReplacementCommand(command, original);
    }
    if (command.businessPurpose == BusinessPurpose.reimbursementClose) {
      return _buildReimbursementCloseReplacementCommand(command, original);
    }

    final transaction = original.transaction;
    final amount = command.amount;
    if (amount.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'replacement_amount_not_positive',
          message: 'Replacement amount must be positive.',
        ),
      );
    }

    return Result.success(
      PostTransactionCommand(
        businessPurpose: command.businessPurpose,
        occurredAt: command.occurredAt,
        currencyCode: amount.currency,
        primaryAmount: amount,
        counterpartyName: command.counterpartyName,
        note: command.note,
        rootTransactionId: transaction.rootTransactionId,
        parentTransactionId: transaction.parentTransactionId,
        reimbursementExpenseAccountId:
            command.businessPurpose == BusinessPurpose.reimbursementAdvance
                ? base.expenseAccountId
                : null,
        mutationKind: MutationKind.correction,
        mutationPreviousTransactionId: transaction.id,
        isExcludedFromStats:
            command.isExcludedFromStats ?? transaction.isExcludedFromStats,
        isExcludedFromBudget:
            command.isExcludedFromBudget ?? transaction.isExcludedFromBudget,
        sourceKind: transaction.sourceKind,
        ownership: transaction.ownership,
        details: _replacementDetails(command.businessPurpose, amount),
        entries: _replacementEntries(command.businessPurpose, base, amount),
      ),
    );
  }

  Future<Failure?> _validateReplacementRoles(_ReplacementStructure structure) {
    return switch (structure.businessPurpose) {
      BusinessPurpose.dailyExpense => _validateAccountConstraints(
        usages: {structure.paidFromAccountId!: AccountUsage.settlement},
        types: {
          structure.expenseAccountId!: {AccountType.expense},
        },
      ),
      BusinessPurpose.reimbursementAdvance => _validateAccountConstraints(
        usages: {
          structure.receivableAccountId!: AccountUsage.reimbursement,
          structure.paidFromAccountId!: AccountUsage.settlement,
        },
        types: {
          structure.expenseAccountId!: {AccountType.expense},
        },
      ),
      BusinessPurpose.dailyIncome => _validateAccountConstraints(
        usages: {structure.receiveAccountId!: AccountUsage.settlement},
        types: {
          structure.incomeAccountId!: {AccountType.income},
        },
      ),
      BusinessPurpose.refund => _validateAccountUsages({
        structure.receiveAccountId!: AccountUsage.settlement,
      }),
      BusinessPurpose.reimbursementReceipt ||
      BusinessPurpose.reimbursementClose => _validateAccountUsages({
        structure.receivableAccountId!: AccountUsage.reimbursement,
        structure.receiveAccountId!: AccountUsage.settlement,
      }),
      BusinessPurpose.transfer => _validateAccountUsages({
        structure.fromAccountId!: AccountUsage.settlement,
        structure.toAccountId!: AccountUsage.settlement,
      }),
      BusinessPurpose.borrowing => _validateAccountUsages({
        structure.liabilityAccountId!: AccountUsage.borrowingLiability,
        if (structure.receiveAccountId != null)
          structure.receiveAccountId!: AccountUsage.fund,
      }),
      BusinessPurpose.debtRepayment => _validateAccountConstraints(
        usages: {
          structure.liabilityAccountId!: AccountUsage.repaymentTarget,
          structure.paidFromAccountId!: AccountUsage.repaymentSource,
        },
      ),
      _ => Future.value(
        const Failure(
          code: 'replacement_purpose_unsupported',
          message: 'Replacement transaction type is unsupported.',
        ),
      ),
    };
  }

  List<PostTransactionDetailInput> _replacementDetails(
    BusinessPurpose purpose,
    Money amount,
  ) {
    final type = switch (purpose) {
      BusinessPurpose.dailyExpense => TransactionDetailType.primaryExpense,
      BusinessPurpose.dailyIncome => TransactionDetailType.primaryIncome,
      BusinessPurpose.transfer => TransactionDetailType.transferMain,
      BusinessPurpose.reimbursementAdvance =>
        TransactionDetailType.reimbursementAdvanceMain,
      BusinessPurpose.refund => TransactionDetailType.refundMain,
      BusinessPurpose.reimbursementReceipt =>
        TransactionDetailType.reimbursementReceiptMain,
      BusinessPurpose.debtRepayment => TransactionDetailType.repaymentPrincipal,
      BusinessPurpose.borrowing => TransactionDetailType.borrowingPrincipal,
      _ => TransactionDetailType.primaryExpense,
    };
    return [PostTransactionDetailInput(lineNo: 1, type: type, amount: amount)];
  }

  List<PostEntryInput> _replacementEntries(
    BusinessPurpose purpose,
    _ReplacementStructure structure,
    Money amount,
  ) {
    return switch (purpose) {
      BusinessPurpose.dailyExpense => [
        PostEntryInput(
          accountId: structure.expenseAccountId!,
          direction: EntryDirection.debit,
          amount: amount,
        ),
        PostEntryInput(
          accountId: structure.paidFromAccountId!,
          direction: EntryDirection.credit,
          amount: amount,
        ),
      ],
      BusinessPurpose.reimbursementAdvance => [
        PostEntryInput(
          accountId: structure.receivableAccountId!,
          direction: EntryDirection.debit,
          amount: amount,
        ),
        PostEntryInput(
          accountId: structure.paidFromAccountId!,
          direction: EntryDirection.credit,
          amount: amount,
        ),
      ],
      BusinessPurpose.dailyIncome => [
        PostEntryInput(
          accountId: structure.receiveAccountId!,
          direction: EntryDirection.debit,
          amount: amount,
        ),
        PostEntryInput(
          accountId: structure.incomeAccountId!,
          direction: EntryDirection.credit,
          amount: amount,
        ),
      ],
      BusinessPurpose.refund => [
        PostEntryInput(
          accountId: structure.receiveAccountId!,
          direction: EntryDirection.debit,
          amount: amount,
        ),
        PostEntryInput(
          accountId: structure.expenseAccountId!,
          direction: EntryDirection.credit,
          amount: amount,
        ),
      ],
      BusinessPurpose.reimbursementReceipt => [
        PostEntryInput(
          accountId: structure.receiveAccountId!,
          direction: EntryDirection.debit,
          amount: amount,
        ),
        PostEntryInput(
          accountId: structure.receivableAccountId!,
          direction: EntryDirection.credit,
          amount: amount,
        ),
      ],
      BusinessPurpose.transfer => [
        PostEntryInput(
          accountId: structure.toAccountId!,
          direction: EntryDirection.debit,
          amount: amount,
        ),
        PostEntryInput(
          accountId: structure.fromAccountId!,
          direction: EntryDirection.credit,
          amount: amount,
        ),
      ],
      BusinessPurpose.borrowing => [
        PostEntryInput(
          accountId: structure.receiveAccountId!,
          direction: EntryDirection.debit,
          amount: amount,
        ),
        PostEntryInput(
          accountId: structure.liabilityAccountId!,
          direction: EntryDirection.credit,
          amount: amount,
        ),
      ],
      BusinessPurpose.debtRepayment => [
        PostEntryInput(
          accountId: structure.liabilityAccountId!,
          direction: EntryDirection.debit,
          amount: amount,
        ),
        PostEntryInput(
          accountId: structure.paidFromAccountId!,
          direction: EntryDirection.credit,
          amount: amount,
        ),
      ],
      _ => const [],
    };
  }

  Future<Result<PostTransactionCommand>> _buildRefundReplacementCommand(
    _CorrectTransactionDraft command,
    TransactionDetailView original,
  ) async {
    final amount = command.amount;
    if (amount.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'refund_amount_not_positive',
          message: 'Refund amount must be positive.',
        ),
      );
    }

    final query = _queryRepository;
    final transaction = original.transaction;
    final parentId = transaction.parentTransactionId;
    if (parentId == null) {
      return const Result.failure(
        Failure(
          code: 'refund_parent_not_found',
          message: 'Original expense not found.',
        ),
      );
    }
    final parent = await query.findTransactionById(parentId);
    if (parent == null) {
      return const Result.failure(
        Failure(
          code: 'refund_parent_not_found',
          message: 'Original expense not found.',
        ),
      );
    }
    if (parent.businessPurpose != BusinessPurpose.dailyExpense &&
        parent.businessPurpose != BusinessPurpose.reimbursementAdvance) {
      return const Result.failure(
        Failure(
          code: 'refund_parent_not_expense',
          message: 'Refund can only be applied to an expense transaction.',
        ),
      );
    }
    if (parent.businessPurpose == BusinessPurpose.reimbursementAdvance) {
      final summary = await query.getReimbursementSummary(
        parent.rootTransactionId,
      );
      if (summary?.isClosed ?? false) {
        return const Result.failure(
          Failure(
            code: 'refund_parent_reimbursement_closed',
            message: 'Refund is not supported after reimbursement is closed.',
          ),
        );
      }
    }
    if (parent.businessState != BusinessState.current) {
      return const Result.failure(
        Failure(
          code: 'refund_parent_not_current',
          message: 'Refund can only be applied to a current expense.',
        ),
      );
    }
    if (parent.currencyCode != amount.currency) {
      return const Result.failure(
        Failure(
          code: 'refund_currency_mismatch',
          message: 'Refund currency must match the original expense.',
        ),
      );
    }

    final refunded = await query.getRefundedTotal(
      parent.rootTransactionId,
      currencyCode: parent.currencyCode,
    );
    final remaining =
        parent.primaryAmount - refunded + transaction.primaryAmount;
    if (amount.minorUnits > remaining.minorUnits) {
      return Result.failure(
        Failure(
          code: 'refund_exceeds_remaining',
          message:
              'Refund exceeds remaining refundable amount '
              '(${remaining.format(withCurrency: true)}).',
        ),
      );
    }

    final refundCreditAccountId =
        await _findRefundCreditAccountIdInParentEntries(
          parentId: parent.id,
          parentPurpose: parent.businessPurpose,
        );
    if (refundCreditAccountId == null) {
      return const Result.failure(
        Failure(
          code: 'refund_expense_account_not_found',
          message: 'Original refund target account cannot be located.',
        ),
      );
    }

    return Result.success(
      PostTransactionCommand(
        businessPurpose: BusinessPurpose.refund,
        occurredAt: command.occurredAt,
        currencyCode: amount.currency,
        primaryAmount: amount,
        counterpartyName: command.counterpartyName,
        note: command.note,
        rootTransactionId: transaction.rootTransactionId,
        parentTransactionId: transaction.parentTransactionId,
        mutationKind: MutationKind.correction,
        mutationPreviousTransactionId: transaction.id,
        isExcludedFromStats:
            command.isExcludedFromStats ?? transaction.isExcludedFromStats,
        isExcludedFromBudget:
            command.isExcludedFromBudget ?? transaction.isExcludedFromBudget,
        sourceKind: transaction.sourceKind,
        ownership: transaction.ownership,
        details: [
          PostTransactionDetailInput(
            lineNo: 1,
            type: TransactionDetailType.refundMain,
            amount: amount,
          ),
        ],
        entries: [
          PostEntryInput(
            accountId: command.receiveAccountId!,
            direction: EntryDirection.debit,
            amount: amount,
          ),
          PostEntryInput(
            accountId: refundCreditAccountId,
            direction: EntryDirection.credit,
            amount: amount,
          ),
        ],
      ),
    );
  }

  Future<Result<PostTransactionCommand>>
  _buildReimbursementReceiptReplacementCommand(
    _CorrectTransactionDraft command,
    TransactionDetailView original,
  ) async {
    final amount = command.amount;
    if (amount.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_amount_not_positive',
          message: 'Receipt amount must be positive.',
        ),
      );
    }

    final query = _queryRepository;
    final transaction = original.transaction;
    final advance = await query.findTransactionById(
      transaction.parentTransactionId ?? transaction.rootTransactionId,
    );
    final advanceFailure = _validateAdvance(advance, amount.currency);
    if (advanceFailure != null) {
      return Result.failure(advanceFailure);
    }
    final summary = await query.getReimbursementSummary(advance!.id);
    if (summary == null) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_summary_unavailable',
          message: 'Cannot resolve reimbursement state.',
        ),
      );
    }
    if (summary.isClosed) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_already_closed',
          message: 'This reimbursement chain is already closed.',
        ),
      );
    }
    final remaining = summary.outstanding + transaction.primaryAmount;
    if (amount.minorUnits > remaining.minorUnits) {
      return Result.failure(
        Failure(
          code: 'reimbursement_receipt_exceeds_outstanding',
          message:
              'Receipt exceeds outstanding receivable '
              '(${remaining.format(withCurrency: true)}).',
        ),
      );
    }

    return Result.success(
      PostTransactionCommand(
        businessPurpose: BusinessPurpose.reimbursementReceipt,
        occurredAt: command.occurredAt,
        currencyCode: amount.currency,
        primaryAmount: amount,
        counterpartyName: command.counterpartyName,
        note: command.note,
        rootTransactionId: transaction.rootTransactionId,
        parentTransactionId: transaction.parentTransactionId,
        mutationKind: MutationKind.correction,
        mutationPreviousTransactionId: transaction.id,
        isExcludedFromStats:
            command.isExcludedFromStats ?? transaction.isExcludedFromStats,
        isExcludedFromBudget:
            command.isExcludedFromBudget ?? transaction.isExcludedFromBudget,
        sourceKind: transaction.sourceKind,
        ownership: transaction.ownership,
        details: [
          PostTransactionDetailInput(
            lineNo: 1,
            type: TransactionDetailType.reimbursementReceiptMain,
            amount: amount,
          ),
        ],
        entries: [
          PostEntryInput(
            accountId: command.receiveAccountId!,
            direction: EntryDirection.debit,
            amount: amount,
          ),
          PostEntryInput(
            accountId: command.receivableAccountId!,
            direction: EntryDirection.credit,
            amount: amount,
          ),
        ],
      ),
    );
  }

  Future<Result<PostTransactionCommand>>
  _buildReimbursementCloseReplacementCommand(
    _CorrectTransactionDraft command,
    TransactionDetailView original,
  ) async {
    final actual = command.amount;
    if (actual.minorUnits < 0) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_close_amount_negative',
          message: 'Final receipt amount cannot be negative.',
        ),
      );
    }

    final transaction = original.transaction;
    final outstanding = _detailAmount(
      original,
      TransactionDetailType.reimbursementCloseMain,
    );
    if (outstanding == null) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_close_structure_invalid',
          message: 'Reimbursement close transaction structure is invalid.',
        ),
      );
    }
    if (actual.currency != outstanding.currency) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_currency_mismatch',
          message: 'Currency must match the reimbursement advance.',
        ),
      );
    }

    final query = _queryRepository;
    final advance = await query.findTransactionById(
      transaction.parentTransactionId ?? transaction.rootTransactionId,
    );
    final advanceFailure = _validateAdvance(advance, actual.currency);
    if (advanceFailure != null) {
      return Result.failure(advanceFailure);
    }

    final gap = actual - outstanding;
    final hasOverGap = gap.minorUnits > 0;
    final hasUnderGap = gap.minorUnits < 0;
    final details = <PostTransactionDetailInput>[
      PostTransactionDetailInput(
        lineNo: 1,
        type: TransactionDetailType.reimbursementCloseMain,
        amount: outstanding,
      ),
      if (hasOverGap)
        PostTransactionDetailInput(
          lineNo: 2,
          type: TransactionDetailType.reimbursementGapIncome,
          amount: gap,
        ),
      if (hasUnderGap)
        PostTransactionDetailInput(
          lineNo: 2,
          type: TransactionDetailType.reimbursementGapExpense,
          amount: gap.abs(),
        ),
    ];
    final entries = <PostEntryInput>[
      if (actual.minorUnits > 0)
        PostEntryInput(
          accountId: command.receiveAccountId!,
          direction: EntryDirection.debit,
          amount: actual,
        ),
      PostEntryInput(
        accountId: command.receivableAccountId!,
        direction: EntryDirection.credit,
        amount: outstanding,
      ),
    ];

    if (hasOverGap) {
      final gapAccountId = await _systemAccounts
          .resolveReimbursementGapIncome(currencyCode: actual.currency);
      entries.add(
        PostEntryInput(
          accountId: gapAccountId,
          direction: EntryDirection.credit,
          amount: gap,
        ),
      );
    } else if (hasUnderGap) {
      final originalExpenseId = advance!.reimbursementExpenseAccountId;
      if (originalExpenseId == null) {
        return const Result.failure(
          Failure(
            code: 'reimbursement_close_expense_missing',
            message: 'Original reimbursement expense category is not recorded.',
          ),
        );
      }
      entries.add(
        PostEntryInput(
          accountId: originalExpenseId,
          direction: EntryDirection.debit,
          amount: gap.abs(),
        ),
      );
    }

    return Result.success(
      PostTransactionCommand(
        businessPurpose: BusinessPurpose.reimbursementClose,
        occurredAt: command.occurredAt,
        currencyCode: actual.currency,
        primaryAmount: actual.minorUnits > 0 ? actual : outstanding,
        counterpartyName: command.counterpartyName,
        note: command.note,
        rootTransactionId: transaction.rootTransactionId,
        parentTransactionId: transaction.parentTransactionId,
        reimbursementExpenseAccountId:
            transaction.reimbursementExpenseAccountId ??
            advance!.reimbursementExpenseAccountId,
        mutationKind: MutationKind.correction,
        mutationPreviousTransactionId: transaction.id,
        isExcludedFromStats:
            command.isExcludedFromStats ?? transaction.isExcludedFromStats,
        isExcludedFromBudget:
            command.isExcludedFromBudget ?? transaction.isExcludedFromBudget,
        sourceKind: transaction.sourceKind,
        ownership: transaction.ownership,
        details: details,
        entries: entries,
      ),
    );
  }

  Future<Result<PostTransactionCommand>> _buildRepaymentReplacementCommand(
    _CorrectTransactionDraft command,
    TransactionDetailView original,
  ) async {
    final principal = command.amount;
    final interest = command.repaymentInterest;
    final fee = command.repaymentFee;
    final discount = command.repaymentDiscount;
    if (principal.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'repayment_principal_not_positive',
          message: 'Repayment principal must be positive.',
        ),
      );
    }
    if (interest != null && interest.currency != principal.currency) {
      return const Result.failure(
        Failure(
          code: 'repayment_currency_mismatch',
          message: 'Repayment interest currency mismatch.',
        ),
      );
    }
    if (fee != null && fee.currency != principal.currency) {
      return const Result.failure(
        Failure(
          code: 'repayment_currency_mismatch',
          message: 'Repayment fee currency mismatch.',
        ),
      );
    }
    if (discount != null && discount.currency != principal.currency) {
      return const Result.failure(
        Failure(
          code: 'repayment_currency_mismatch',
          message: 'Repayment discount currency mismatch.',
        ),
      );
    }

    final hasInterest = interest != null && interest.minorUnits > 0;
    final hasFee = fee != null && fee.minorUnits > 0;
    final hasDiscount = discount != null && discount.minorUnits > 0;
    if (hasFee && command.feeExpenseAccountId == null) {
      return const Result.failure(
        Failure(
          code: 'repayment_fee_account_required',
          message: 'Fee category is required when fee is positive.',
        ),
      );
    }

    final totalPaid =
        principal +
        (hasInterest ? interest : Money.zero(currency: principal.currency)) +
        (hasFee ? fee : Money.zero(currency: principal.currency)) -
        (hasDiscount ? discount : Money.zero(currency: principal.currency));
    if (totalPaid.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'repayment_total_paid_not_positive',
          message: 'Repayment total paid must be positive.',
        ),
      );
    }

    final interestExpenseAccountId =
        hasInterest && command.interestExpenseAccountId == null
            ? await _systemAccounts.resolveDebtInterestExpense(
              currencyCode: principal.currency,
            )
            : command.interestExpenseAccountId;
    final discountIncomeAccountId =
        hasDiscount
            ? await _systemAccounts.resolveDiscountIncome(
              currencyCode: principal.currency,
            )
            : null;

    final roleFailure = await _validateAccountConstraints(
      usages: {
        command.liabilityAccountId!: AccountUsage.repaymentTarget,
        command.paidFromAccountId!: AccountUsage.repaymentSource,
      },
      types: {
        if (hasInterest) interestExpenseAccountId!: {AccountType.expense},
        if (hasFee) command.feeExpenseAccountId!: {AccountType.expense},
        if (hasDiscount) discountIncomeAccountId!: {AccountType.income},
      },
    );
    if (roleFailure != null) {
      return Result.failure(roleFailure);
    }

    final transaction = original.transaction;
    return Result.success(
      PostTransactionCommand(
        businessPurpose: BusinessPurpose.debtRepayment,
        occurredAt: command.occurredAt,
        currencyCode: principal.currency,
        primaryAmount: totalPaid,
        counterpartyName: command.counterpartyName,
        note: command.note,
        rootTransactionId: transaction.rootTransactionId,
        parentTransactionId: transaction.parentTransactionId,
        mutationKind: MutationKind.correction,
        mutationPreviousTransactionId: transaction.id,
        isExcludedFromStats:
            command.isExcludedFromStats ?? transaction.isExcludedFromStats,
        isExcludedFromBudget:
            command.isExcludedFromBudget ?? transaction.isExcludedFromBudget,
        sourceKind: transaction.sourceKind,
        ownership: transaction.ownership,
        details: [
          PostTransactionDetailInput(
            lineNo: 1,
            type: TransactionDetailType.repaymentPrincipal,
            amount: principal,
          ),
          if (hasInterest)
            PostTransactionDetailInput(
              lineNo: 2,
              type: TransactionDetailType.repaymentInterest,
              amount: interest,
            ),
          if (hasFee)
            PostTransactionDetailInput(
              lineNo: hasInterest ? 3 : 2,
              type: TransactionDetailType.repaymentFee,
              amount: fee,
            ),
          if (hasDiscount)
            PostTransactionDetailInput(
              lineNo: 2 + (hasInterest ? 1 : 0) + (hasFee ? 1 : 0),
              type: TransactionDetailType.repaymentDiscount,
              amount: discount,
            ),
        ],
        entries: [
          PostEntryInput(
            accountId: command.liabilityAccountId!,
            direction: EntryDirection.debit,
            amount: principal,
          ),
          if (hasInterest)
            PostEntryInput(
              accountId: interestExpenseAccountId!,
              direction: EntryDirection.debit,
              amount: interest,
            ),
          if (hasFee)
            PostEntryInput(
              accountId: command.feeExpenseAccountId!,
              direction: EntryDirection.debit,
              amount: fee,
            ),
          if (hasDiscount)
            PostEntryInput(
              accountId: discountIncomeAccountId!,
              direction: EntryDirection.credit,
              amount: discount,
            ),
          PostEntryInput(
            accountId: command.paidFromAccountId!,
            direction: EntryDirection.credit,
            amount: totalPaid,
          ),
        ],
      ),
    );
  }

  Money? _detailAmount(
    TransactionDetailView detail,
    TransactionDetailType type,
  ) {
    for (final line in detail.details) {
      if (line.type == type) {
        return line.amount;
      }
    }
    return null;
  }

  _ReplacementStructure _replacementStructure(
    _CorrectTransactionDraft command,
  ) {
    return _ReplacementStructure(
      businessPurpose: command.businessPurpose,
      paidFromAccountId: command.paidFromAccountId,
      expenseAccountId: command.expenseAccountId,
      receivableAccountId: command.receivableAccountId,
      receiveAccountId: command.receiveAccountId,
      incomeAccountId: command.incomeAccountId,
      fromAccountId: command.fromAccountId,
      toAccountId: command.toAccountId,
      liabilityAccountId: command.liabilityAccountId,
    );
  }

  bool _matchesOriginalStructure(
    TransactionDetailView original,
    _ReplacementStructure replacement,
  ) {
    final transaction = original.transaction;
    if (transaction.businessPurpose != replacement.businessPurpose) {
      return false;
    }
    final entries = original.entries;
    int? firstAccount(AccountType type, EntryDirection direction) {
      for (final entry in entries) {
        if (entry.accountType == type && entry.direction == direction) {
          return entry.accountId;
        }
      }
      return null;
    }

    int? firstAsset(EntryDirection direction) {
      for (final entry in entries) {
        if ((entry.accountType == AccountType.asset ||
                entry.accountType == AccountType.liability) &&
            entry.direction == direction) {
          return entry.accountId;
        }
      }
      return null;
    }

    return switch (transaction.businessPurpose) {
      BusinessPurpose.dailyExpense =>
        replacement.expenseAccountId ==
                firstAccount(AccountType.expense, EntryDirection.debit) &&
            replacement.paidFromAccountId == firstAsset(EntryDirection.credit),
      BusinessPurpose.reimbursementAdvance =>
        replacement.expenseAccountId ==
                transaction.reimbursementExpenseAccountId &&
            replacement.receivableAccountId ==
                firstAsset(EntryDirection.debit) &&
            replacement.paidFromAccountId == firstAsset(EntryDirection.credit),
      BusinessPurpose.refund =>
        replacement.receiveAccountId == firstAsset(EntryDirection.debit),
      BusinessPurpose.reimbursementReceipt ||
      BusinessPurpose.reimbursementClose =>
        replacement.receivableAccountId == firstAsset(EntryDirection.credit) &&
            replacement.receiveAccountId == firstAsset(EntryDirection.debit),
      BusinessPurpose.dailyIncome =>
        replacement.incomeAccountId ==
                firstAccount(AccountType.income, EntryDirection.credit) &&
            replacement.receiveAccountId == firstAsset(EntryDirection.debit),
      BusinessPurpose.transfer =>
        replacement.fromAccountId == firstAsset(EntryDirection.credit) &&
            replacement.toAccountId == firstAsset(EntryDirection.debit),
      BusinessPurpose.borrowing =>
        replacement.liabilityAccountId ==
                firstAccount(AccountType.liability, EntryDirection.credit) &&
            replacement.receiveAccountId == firstAsset(EntryDirection.debit),
      BusinessPurpose.debtRepayment =>
        replacement.liabilityAccountId ==
                firstAccount(AccountType.liability, EntryDirection.debit) &&
            replacement.paidFromAccountId == firstAsset(EntryDirection.credit),
      _ => false,
    };
  }

  Failure? _validateAdvance(Transaction? advance, String currencyCode) {
    if (advance == null) {
      return const Failure(
        code: 'reimbursement_advance_not_found',
        message: 'Reimbursement advance not found.',
      );
    }
    if (advance.businessPurpose != BusinessPurpose.reimbursementAdvance) {
      return const Failure(
        code: 'reimbursement_parent_not_advance',
        message: 'Parent transaction is not a reimbursement advance.',
      );
    }
    if (advance.businessState != BusinessState.current) {
      return const Failure(
        code: 'reimbursement_advance_not_current',
        message: 'Reimbursement advance is not current.',
      );
    }
    if (advance.currencyCode != currencyCode) {
      return const Failure(
        code: 'reimbursement_currency_mismatch',
        message: 'Currency must match the reimbursement advance.',
      );
    }
    return null;
  }

  Future<int?> _findRefundCreditAccountIdInParentEntries({
    required int parentId,
    required BusinessPurpose parentPurpose,
  }) async {
    final query = _queryRepository;
    final view = await query.watchTransactionDetail(parentId).first;
    if (view == null) return null;
    for (final entry in view.entries) {
      final isDailyExpenseTarget =
          parentPurpose == BusinessPurpose.dailyExpense &&
          entry.accountType == AccountType.expense &&
          entry.direction == EntryDirection.debit;
      final isAdvanceTarget =
          parentPurpose == BusinessPurpose.reimbursementAdvance &&
          entry.accountType == AccountType.asset &&
          entry.direction == EntryDirection.debit;
      if (isDailyExpenseTarget || isAdvanceTarget) {
        return entry.accountId;
      }
    }
    return null;
  }

  Future<Failure?> _validateAccountConstraints({
    Map<int, Set<AccountType>> types = const {},
    Map<int, AccountUsage> usages = const {},
  }) async {
    final typeFailure = await _validateAccountRoles(types);
    if (typeFailure != null) {
      return typeFailure;
    }
    return _validateAccountUsages(usages);
  }

  Future<Failure?> _validateAccountUsages(
    Map<int, AccountUsage> expectedUsageByAccountId,
  ) async {
    final repository = _accountRepository;
    if (expectedUsageByAccountId.isEmpty) {
      return null;
    }

    final accounts = await repository.findAccountsByIds(
      expectedUsageByAccountId.keys.toSet(),
    );
    final accountsById = {for (final account in accounts) account.id: account};

    for (final MapEntry(key: accountId, value: usage)
        in expectedUsageByAccountId.entries) {
      final account = accountsById[accountId];
      if (account == null) {
        return Failure(
          code: 'account_not_found',
          message: 'Account $accountId does not exist.',
        );
      }
      if (!accountMatchesUsage(account, usage)) {
        return Failure(
          code:
              account.archivedAt == null
                  ? 'account_role_invalid'
                  : 'account_archived',
          message: 'Account $accountId cannot be used for this transaction.',
        );
      }
    }

    return null;
  }

  Future<Failure?> _validateAccountRoles(
    Map<int, Set<AccountType>> expectedTypesByAccountId,
  ) async {
    final repository = _accountRepository;
    if (expectedTypesByAccountId.isEmpty) {
      return null;
    }

    final accounts = await repository.findAccountsByIds(
      expectedTypesByAccountId.keys.toSet(),
    );
    final accountsById = {for (final account in accounts) account.id: account};

    for (final MapEntry(key: accountId, value: expectedTypes)
        in expectedTypesByAccountId.entries) {
      final account = accountsById[accountId];
      if (account == null) {
        return Failure(
          code: 'account_not_found',
          message: 'Account $accountId does not exist.',
        );
      }
      if (account.archivedAt != null) {
        return Failure(
          code: 'account_archived',
          message: 'Account $accountId is archived.',
        );
      }
      if (!expectedTypes.contains(account.type)) {
        return Failure(
          code: 'account_role_invalid',
          message: 'Account $accountId cannot be used for this transaction.',
        );
      }
    }

    return null;
  }
}

class _CorrectTransactionDraft {
  const _CorrectTransactionDraft({
    required this.transactionId,
    required this.businessPurpose,
    required this.amount,
    required this.occurredAt,
    this.paidFromAccountId,
    this.expenseAccountId,
    this.receivableAccountId,
    this.receiveAccountId,
    this.incomeAccountId,
    this.fromAccountId,
    this.toAccountId,
    this.liabilityAccountId,
    this.repaymentInterest,
    this.repaymentFee,
    this.repaymentDiscount,
    this.interestExpenseAccountId,
    this.feeExpenseAccountId,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats,
    this.isExcludedFromBudget,
  });

  final int transactionId;
  final BusinessPurpose businessPurpose;
  final Money amount;
  final DateTime occurredAt;
  final int? paidFromAccountId;
  final int? expenseAccountId;
  final int? receivableAccountId;
  final int? receiveAccountId;
  final int? incomeAccountId;
  final int? fromAccountId;
  final int? toAccountId;
  final int? liabilityAccountId;
  final Money? repaymentInterest;
  final Money? repaymentFee;
  final Money? repaymentDiscount;
  final int? interestExpenseAccountId;
  final int? feeExpenseAccountId;
  final String? counterpartyName;
  final String? note;
  final bool? isExcludedFromStats;
  final bool? isExcludedFromBudget;
}

class _ReplacementStructure {
  const _ReplacementStructure({
    required this.businessPurpose,
    this.paidFromAccountId,
    this.expenseAccountId,
    this.receivableAccountId,
    this.receiveAccountId,
    this.incomeAccountId,
    this.fromAccountId,
    this.toAccountId,
    this.liabilityAccountId,
  });

  final BusinessPurpose businessPurpose;
  final int? paidFromAccountId;
  final int? expenseAccountId;
  final int? receivableAccountId;
  final int? receiveAccountId;
  final int? incomeAccountId;
  final int? fromAccountId;
  final int? toAccountId;
  final int? liabilityAccountId;
}
