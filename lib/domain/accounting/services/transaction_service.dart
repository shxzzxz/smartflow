import '../../../core/errors/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../../../core/result/result.dart';
import '../commands/transaction_commands.dart';
import '../entities/account_usage.dart';
import '../entities/entry.dart';
import '../enums/accounting_enums.dart';
import '../ledger/post_receipt.dart';
import '../ledger/poster.dart';
import '../ledger/receipt_builder.dart';
import '../read_models/transaction_read_models.dart';
import '../repositories/account_repository.dart';
import '../repositories/posting_repository.dart';
import 'transaction_query_service.dart';

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
  TransactionServiceImpl({
    required Poster poster,
    required ReceiptBuilder receiptBuilder,
    required TransactionQueryService transactionQueryService,
    required AccountRepository accountRepository,
    required PostingRepository postingRepository,
  }) : _poster = poster,
       _receipts = receiptBuilder,
       _query = transactionQueryService,
       _accountRepository = accountRepository,
       _postingRepository = postingRepository;

  final Poster _poster;
  final ReceiptBuilder _receipts;
  final TransactionQueryService _query;
  final AccountRepository _accountRepository;
  final PostingRepository _postingRepository;

  // ============================================================
  //  Create
  // ============================================================

  @override
  Future<Result<CreatedTransactionResult>> createExpense(
    CreateExpenseCommand command,
  ) => _runCreate(_receipts.buildExpense(command));

  @override
  Future<Result<CreatedTransactionResult>> createIncome(
    CreateIncomeCommand command,
  ) => _runCreate(_receipts.buildIncome(command));

  @override
  Future<Result<CreatedTransactionResult>> createTransfer(
    CreateTransferCommand command,
  ) => _runCreate(_receipts.buildTransfer(command));

  @override
  Future<Result<CreatedTransactionResult>> createRefund(
    CreateRefundCommand command,
  ) => _runCreate(_receipts.buildRefund(command));

  @override
  Future<Result<CreatedTransactionResult>> createReimbursementAdvance(
    CreateReimbursementAdvanceCommand command,
  ) => _runCreate(_receipts.buildReimbursementAdvance(command));

  @override
  Future<Result<CreatedTransactionResult>> createReimbursementReceipt(
    CreateReimbursementReceiptCommand command,
  ) => _runCreate(_receipts.buildReimbursementReceipt(command));

  @override
  Future<Result<CreatedTransactionResult>> closeReimbursement(
    CloseReimbursementCommand command,
  ) => _runCreate(_receipts.buildReimbursementClose(command));

  @override
  Future<Result<CreatedTransactionResult>> createRepayment(
    CreateRepaymentCommand command,
  ) => _runCreate(_receipts.buildRepayment(command));

  @override
  Future<Result<CreatedTransactionResult>> createBorrowing(
    CreateBorrowingCommand command,
  ) => _runCreate(_receipts.buildBorrowing(command));

  @override
  Future<Result<CreatedTransactionResult>> createOpeningBalance(
    CreateOpeningBalanceCommand command,
  ) => _runCreate(_receipts.buildOpeningBalance(command));

  @override
  Future<Result<CreatedTransactionResult>> adjustBalance(
    AdjustBalanceCommand command,
  ) => _runCreate(_receipts.buildBalanceAdjustment(command));

  // ============================================================
  //  Correct
  // ============================================================

  @override
  Future<Result<CreatedTransactionResult>> correctExpense(
    CorrectExpenseCommand cmd,
  ) {
    return _runCorrection(
      transactionId: cmd.transactionId,
      expectedPurpose: BusinessPurpose.dailyExpense,
      build: (original) => _receipts.buildExpense(
        CreateExpenseCommand(
          amount: cmd.amount,
          paidFromAccountId: cmd.paidFromAccountId,
          expenseAccountId: cmd.expenseAccountId,
          occurredAt: cmd.occurredAt,
          counterpartyName: cmd.counterpartyName,
          note: cmd.note,
          isExcludedFromStats: cmd.isExcludedFromStats ??
              original.transaction.isExcludedFromStats,
          isExcludedFromBudget: cmd.isExcludedFromBudget ??
              original.transaction.isExcludedFromBudget,
        ),
      ),
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctIncome(
    CorrectIncomeCommand cmd,
  ) {
    return _runCorrection(
      transactionId: cmd.transactionId,
      expectedPurpose: BusinessPurpose.dailyIncome,
      build: (original) => _receipts.buildIncome(
        CreateIncomeCommand(
          amount: cmd.amount,
          receiveAccountId: cmd.receiveAccountId,
          incomeAccountId: cmd.incomeAccountId,
          occurredAt: cmd.occurredAt,
          counterpartyName: cmd.counterpartyName,
          note: cmd.note,
          isExcludedFromStats: cmd.isExcludedFromStats ??
              original.transaction.isExcludedFromStats,
          isExcludedFromBudget: cmd.isExcludedFromBudget ??
              original.transaction.isExcludedFromBudget,
        ),
      ),
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctTransfer(
    CorrectTransferCommand cmd,
  ) {
    return _runCorrection(
      transactionId: cmd.transactionId,
      expectedPurpose: BusinessPurpose.transfer,
      build: (original) => _receipts.buildTransfer(
        CreateTransferCommand(
          amount: cmd.amount,
          fromAccountId: cmd.fromAccountId,
          toAccountId: cmd.toAccountId,
          occurredAt: cmd.occurredAt,
          counterpartyName: cmd.counterpartyName,
          note: cmd.note,
          isExcludedFromStats: cmd.isExcludedFromStats ??
              original.transaction.isExcludedFromStats,
          isExcludedFromBudget: cmd.isExcludedFromBudget ??
              original.transaction.isExcludedFromBudget,
        ),
      ),
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctReimbursementAdvance(
    CorrectReimbursementAdvanceCommand cmd,
  ) {
    return _runCorrection(
      transactionId: cmd.transactionId,
      expectedPurpose: BusinessPurpose.reimbursementAdvance,
      build: (original) => _receipts.buildReimbursementAdvance(
        CreateReimbursementAdvanceCommand(
          amount: cmd.amount,
          receivableAccountId: cmd.receivableAccountId,
          paidFromAccountId: cmd.paidFromAccountId,
          expenseCategoryId: cmd.expenseCategoryId,
          occurredAt: cmd.occurredAt,
          counterpartyName: cmd.counterpartyName,
          note: cmd.note,
          isExcludedFromStats: cmd.isExcludedFromStats ??
              original.transaction.isExcludedFromStats,
          isExcludedFromBudget: cmd.isExcludedFromBudget ??
              original.transaction.isExcludedFromBudget,
        ),
      ),
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctRefund(
    CorrectRefundCommand cmd,
  ) {
    return _runCorrection(
      transactionId: cmd.transactionId,
      expectedPurpose: BusinessPurpose.refund,
      build: (original) => _receipts.buildRefund(
        CreateRefundCommand(
          amount: cmd.amount,
          parentTransactionId: original.transaction.parentTransactionId!,
          refundToAccountId: cmd.refundToAccountId,
          occurredAt: cmd.occurredAt,
          counterpartyName: cmd.counterpartyName,
          note: cmd.note,
          isExcludedFromStats: cmd.isExcludedFromStats ??
              original.transaction.isExcludedFromStats,
          isExcludedFromBudget: cmd.isExcludedFromBudget ??
              original.transaction.isExcludedFromBudget,
        ),
        selfPrimaryAddback: original.transaction.primaryAmount,
      ),
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctReimbursementReceipt(
    CorrectReimbursementReceiptCommand cmd,
  ) {
    return _runCorrection(
      transactionId: cmd.transactionId,
      expectedPurpose: BusinessPurpose.reimbursementReceipt,
      build: (original) => _receipts.buildReimbursementReceipt(
        CreateReimbursementReceiptCommand(
          amount: cmd.amount,
          advanceTransactionId: original.transaction.parentTransactionId ??
              original.transaction.rootTransactionId,
          receivableAccountId: cmd.receivableAccountId,
          receiveAccountId: cmd.receiveAccountId,
          occurredAt: cmd.occurredAt,
          counterpartyName: cmd.counterpartyName,
          note: cmd.note,
          isExcludedFromStats: cmd.isExcludedFromStats ??
              original.transaction.isExcludedFromStats,
          isExcludedFromBudget: cmd.isExcludedFromBudget ??
              original.transaction.isExcludedFromBudget,
        ),
        selfPrimaryAddback: original.transaction.primaryAmount,
      ),
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctReimbursementClose(
    CorrectReimbursementCloseCommand cmd,
  ) {
    return _runCorrection(
      transactionId: cmd.transactionId,
      expectedPurpose: BusinessPurpose.reimbursementClose,
      build: (original) => _receipts.buildReimbursementClose(
        CloseReimbursementCommand(
          actualReceivedAmount: cmd.actualReceivedAmount,
          advanceTransactionId: original.transaction.parentTransactionId ??
              original.transaction.rootTransactionId,
          receivableAccountId: cmd.receivableAccountId,
          receiveAccountId: cmd.receiveAccountId,
          occurredAt: cmd.occurredAt,
          counterpartyName: cmd.counterpartyName,
          note: cmd.note,
          isExcludedFromStats: cmd.isExcludedFromStats ??
              original.transaction.isExcludedFromStats,
          isExcludedFromBudget: cmd.isExcludedFromBudget ??
              original.transaction.isExcludedFromBudget,
        ),
        outstandingOverride: _detailAmount(
          original,
          TransactionDetailType.reimbursementCloseMain,
        ),
      ),
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctBorrowing(
    CorrectBorrowingCommand cmd,
  ) {
    return _runCorrection(
      transactionId: cmd.transactionId,
      expectedPurpose: BusinessPurpose.borrowing,
      build: (original) => _receipts.buildBorrowing(
        CreateBorrowingCommand(
          amount: cmd.amount,
          liabilityAccountId: cmd.liabilityAccountId,
          receiveAccountId: cmd.receiveAccountId,
          occurredAt: cmd.occurredAt,
          counterpartyName: cmd.counterpartyName,
          note: cmd.note,
          ownership: original.transaction.ownership,
          isExcludedFromStats: cmd.isExcludedFromStats ??
              original.transaction.isExcludedFromStats,
          isExcludedFromBudget: cmd.isExcludedFromBudget ??
              original.transaction.isExcludedFromBudget,
        ),
      ),
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctRepayment(
    CorrectRepaymentCommand cmd,
  ) {
    return _runCorrection(
      transactionId: cmd.transactionId,
      expectedPurpose: BusinessPurpose.debtRepayment,
      build: (original) => _receipts.buildRepayment(
        CreateRepaymentCommand(
          principal: cmd.principal,
          interest: cmd.interest,
          fee: cmd.fee,
          discount: cmd.discount,
          liabilityAccountId: cmd.liabilityAccountId,
          paidFromAccountId: cmd.paidFromAccountId,
          interestExpenseAccountId: cmd.interestExpenseAccountId,
          feeExpenseAccountId: cmd.feeExpenseAccountId,
          occurredAt: cmd.occurredAt,
          counterpartyName: cmd.counterpartyName,
          note: cmd.note,
          ownership: original.transaction.ownership,
          isExcludedFromStats: cmd.isExcludedFromStats ??
              original.transaction.isExcludedFromStats,
          isExcludedFromBudget: cmd.isExcludedFromBudget ??
              original.transaction.isExcludedFromBudget,
        ),
      ),
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  // ============================================================
  //  Delete
  // ============================================================

  @override
  Future<Result<void>> deleteTransaction(
    DeleteTransactionCommand command,
  ) async {
    final target = await _query.watchTransactionDetail(command.transactionId).first;
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

    final originals = <TransactionDetail>[];
    for (final child in target.children) {
      final childDetail =
          await _query.watchTransactionDetail(child.id).first;
      if (childDetail != null &&
          childDetail.transaction.businessState == BusinessState.current) {
        originals.add(childDetail);
      }
    }
    originals.add(target);

    return _poster.cancel(originals: originals);
  }

  // ============================================================
  //  Metadata-only updates
  // ============================================================

  @override
  Future<Result<void>> updateTransactionMetadata(
    UpdateTransactionMetadataCommand command,
  ) async {
    if (command.note == null &&
        command.isExcludedFromStats == null &&
        command.isExcludedFromBudget == null) {
      return const Result.success(null);
    }
    final transaction =
        await _query.findTransactionById(command.transactionId);
    if (transaction == null) {
      return const Result.failure(
        Failure(
          code: 'transaction_not_found',
          message: 'Transaction does not exist.',
        ),
      );
    }
    try {
      await _postingRepository.updateTransactionMetadata(
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

    final detail =
        await _query.watchTransactionDetail(command.transactionId).first;
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
    final accountTypes = await _receipts.loadAccountTypes(
      detail.entries.map((e) => e.accountId),
    );
    final settlementAccountId = command.settlementAccountId;
    if (settlementAccountId != null) {
      final entry = _settlementEntry(detail, accountTypes);
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
      final entry = _reimbursementReceivableEntry(detail, accountTypes);
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
      await _postingRepository.updateTransactionBasics(
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
    final transaction =
        await _query.findTransactionById(command.transactionId);
    if (transaction == null) {
      return const Result.failure(
        Failure(
          code: 'transaction_not_found',
          message: 'Transaction does not exist.',
        ),
      );
    }
    try {
      await _postingRepository.updateTransactionOwnership(
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

  // ============================================================
  //  内部:create / correct 编排骨架
  // ============================================================

  Future<Result<CreatedTransactionResult>> _runCreate(
    Future<Result<PostReceipt>> receiptFuture,
  ) async {
    final receiptResult = await receiptFuture;
    switch (receiptResult) {
      case FailureResult(:final failure):
        return Result.failure(failure);
      case Success(:final value):
        final post = await _poster.create(value);
        return post.when(
          success: (r) => Result.success(
            CreatedTransactionResult(
              transactionId: r.transactionId,
              rootTransactionId: r.rootTransactionId,
            ),
          ),
          failure: Result.failure,
        );
    }
  }

  Future<Result<CreatedTransactionResult>> _runCorrection({
    required int transactionId,
    required BusinessPurpose expectedPurpose,
    required Future<Result<PostReceipt>> Function(TransactionDetail original)
        build,
    required String? note,
    required bool? isExcludedFromStats,
    required bool? isExcludedFromBudget,
  }) async {
    final original = await _query.watchTransactionDetail(transactionId).first;
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
    if (original.transaction.businessPurpose != expectedPurpose) {
      return const Result.failure(
        Failure(
          code: 'transaction_correction_purpose_mismatch',
          message: 'Correction command purpose must match the transaction.',
        ),
      );
    }

    final receiptResult = await build(original);
    switch (receiptResult) {
      case FailureResult(:final failure):
        return Result.failure(failure);
      case Success(:final value):
        if (original.children.isNotEmpty) {
          if (!structureMatches(value, original)) {
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
              transactionId: transactionId,
              note: note == null
                  ? const Patch<String>.clear()
                  : Patch.set(note),
              isExcludedFromStats: isExcludedFromStats,
              isExcludedFromBudget: isExcludedFromBudget,
            ),
          );
          return metadata.when(
            success: (_) => Result.success(
              CreatedTransactionResult(
                transactionId: original.transaction.id,
                rootTransactionId: original.transaction.rootTransactionId,
              ),
            ),
            failure: Result.failure,
          );
        }
        final post = await _poster.replace(
          original: original,
          newReceipt: value,
        );
        return post.when(
          success: (r) => Result.success(
            CreatedTransactionResult(
              transactionId: r.transactionId,
              rootTransactionId: r.rootTransactionId,
            ),
          ),
          failure: Result.failure,
        );
    }
  }

  // ============================================================
  //  Update basics helpers
  // ============================================================

  Entry? _settlementEntry(
    TransactionDetail detail,
    Map<int, AccountType> accountTypes,
  ) {
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
      final accountType = accountTypes[entry.accountId];
      final settlementType = accountType == AccountType.asset ||
          accountType == AccountType.liability;
      final isReimbursementReceivable = detail.transaction.businessPurpose ==
              BusinessPurpose.reimbursementAdvance &&
          entry.direction == EntryDirection.debit &&
          accountType == AccountType.asset;
      if (settlementType &&
          !isReimbursementReceivable &&
          entry.direction == direction) {
        return entry;
      }
    }
    return null;
  }

  Entry? _reimbursementReceivableEntry(
    TransactionDetail detail,
    Map<int, AccountType> accountTypes,
  ) {
    for (final entry in detail.entries) {
      if (accountTypes[entry.accountId] == AccountType.asset &&
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
    final account = await _accountRepository.findAccountById(accountId);
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

  Money? _detailAmount(
    TransactionDetail detail,
    TransactionDetailType type,
  ) {
    for (final line in detail.details) {
      if (line.type == type) {
        return line.amount;
      }
    }
    return null;
  }
}
