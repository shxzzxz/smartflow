import '../../../core/errors/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../../../core/result/result.dart';
import '../commands/transaction_commands.dart';
import '../entities/account_usage.dart';
import '../entities/entry.dart';
import '../enums/accounting_enums.dart';
import '../ledger/poster.dart';
import '../ledger/posting_protocol.dart';
import '../repositories/account_repository.dart';
import '../repositories/posting_repository.dart';
import '../repositories/system_account_resolver.dart';
import '../read_models/transaction_read_models.dart';
import '../vouchers/balance_adjustment_voucher.dart';
import '../vouchers/borrowing_voucher.dart';
import '../vouchers/expense_voucher.dart';
import '../vouchers/income_voucher.dart';
import '../vouchers/opening_balance_voucher.dart';
import '../vouchers/refund_voucher.dart';
import '../vouchers/reimbursement_advance_voucher.dart';
import '../vouchers/reimbursement_close_voucher.dart';
import '../vouchers/reimbursement_receipt_voucher.dart';
import '../vouchers/repayment_voucher.dart';
import '../vouchers/transaction_voucher.dart';
import '../vouchers/transfer_voucher.dart';
import '../vouchers/voucher_runner.dart';
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
  TransactionServiceImpl(
    this._postingService, {
    required AccountRepository accountRepository,
    required TransactionQueryService transactionQueryService,
    required SystemAccountResolver systemAccountResolver,
    required PostingRepository postingRepository,
  }) : _accountRepository = accountRepository,
       _queryService = transactionQueryService,
       _systemAccounts = systemAccountResolver,
       _postingRepository = postingRepository;

  final Poster _postingService;
  final AccountRepository _accountRepository;
  final TransactionQueryService _queryService;
  final SystemAccountResolver _systemAccounts;
  final PostingRepository _postingRepository;

  late final VoucherContext _voucherContext = VoucherContext(
    accountRepository: _accountRepository,
    queryService: _queryService,
    systemAccountResolver: _systemAccounts,
  );

  late final VoucherRunner _runner = VoucherRunner(
    poster: _postingService,
    context: _voucherContext,
  );

  @override
  Future<Result<CreatedTransactionResult>> createExpense(
    CreateExpenseCommand command,
  ) {
    return _runner.runCreate(
      const ExpenseVoucher(),
      ExpenseVoucherInput(
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
  Future<Result<CreatedTransactionResult>> createIncome(
    CreateIncomeCommand command,
  ) {
    return _runner.runCreate(
      const IncomeVoucher(),
      IncomeVoucherInput(
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
  Future<Result<CreatedTransactionResult>> createTransfer(
    CreateTransferCommand command,
  ) {
    return _runner.runCreate(
      const TransferVoucher(),
      TransferVoucherInput(
        amount: command.amount,
        fromAccountId: command.fromAccountId,
        toAccountId: command.toAccountId,
        occurredAt: command.occurredAt,
        feeAmount: command.feeAmount,
        feeExpenseAccountId: command.feeExpenseAccountId,
        counterpartyName: command.counterpartyName,
        note: command.note,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> createRefund(
    CreateRefundCommand command,
  ) {
    return _runner.runCreate(
      const RefundVoucher(),
      RefundVoucherInput(
        amount: command.amount,
        parentTransactionId: command.parentTransactionId,
        refundToAccountId: command.refundToAccountId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> createReimbursementAdvance(
    CreateReimbursementAdvanceCommand command,
  ) {
    return _runner.runCreate(
      const ReimbursementAdvanceVoucher(),
      ReimbursementAdvanceVoucherInput(
        amount: command.amount,
        receivableAccountId: command.receivableAccountId,
        paidFromAccountId: command.paidFromAccountId,
        expenseCategoryId: command.expenseCategoryId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> createReimbursementReceipt(
    CreateReimbursementReceiptCommand command,
  ) {
    return _runner.runCreate(
      const ReimbursementReceiptVoucher(),
      ReimbursementReceiptVoucherInput(
        amount: command.amount,
        advanceTransactionId: command.advanceTransactionId,
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
  Future<Result<CreatedTransactionResult>> closeReimbursement(
    CloseReimbursementCommand command,
  ) {
    return _runner.runCreate(
      const ReimbursementCloseVoucher(),
      ReimbursementCloseVoucherInput(
        actualReceivedAmount: command.actualReceivedAmount,
        advanceTransactionId: command.advanceTransactionId,
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
  Future<Result<CreatedTransactionResult>> createRepayment(
    CreateRepaymentCommand command,
  ) {
    return _runner.runCreate(
      const RepaymentVoucher(),
      RepaymentVoucherInput(
        principal: command.principal,
        interest: command.interest,
        fee: command.fee,
        discount: command.discount,
        liabilityAccountId: command.liabilityAccountId,
        paidFromAccountId: command.paidFromAccountId,
        interestExpenseAccountId: command.interestExpenseAccountId,
        feeExpenseAccountId: command.feeExpenseAccountId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        ownership: command.ownership,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> createBorrowing(
    CreateBorrowingCommand command,
  ) {
    return _runner.runCreate(
      const BorrowingVoucher(),
      BorrowingVoucherInput(
        amount: command.amount,
        liabilityAccountId: command.liabilityAccountId,
        receiveAccountId: command.receiveAccountId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        ownership: command.ownership,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> createOpeningBalance(
    CreateOpeningBalanceCommand command,
  ) {
    return _runner.runCreate(
      const OpeningBalanceVoucher(),
      OpeningBalanceVoucherInput(
        accountId: command.accountId,
        amount: command.amount,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> adjustBalance(
    AdjustBalanceCommand command,
  ) {
    return _runner.runCreate(
      const BalanceAdjustmentVoucher(),
      BalanceAdjustmentVoucherInput(
        accountId: command.accountId,
        targetBalance: command.targetBalance,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctExpense(
    CorrectExpenseCommand command,
  ) {
    return _runCorrection(
      transactionId: command.transactionId,
      expectedPurpose: BusinessPurpose.dailyExpense,
      note: command.note,
      isExcludedFromStats: command.isExcludedFromStats,
      isExcludedFromBudget: command.isExcludedFromBudget,
      voucher: const ExpenseVoucher(),
      buildInput: (original) => ExpenseVoucherInput(
        amount: command.amount,
        paidFromAccountId: command.paidFromAccountId,
        expenseAccountId: command.expenseAccountId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        isExcludedFromStats:
            command.isExcludedFromStats ??
                original.transaction.isExcludedFromStats,
        isExcludedFromBudget:
            command.isExcludedFromBudget ??
                original.transaction.isExcludedFromBudget,
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctIncome(
    CorrectIncomeCommand command,
  ) {
    return _runCorrection(
      transactionId: command.transactionId,
      expectedPurpose: BusinessPurpose.dailyIncome,
      note: command.note,
      isExcludedFromStats: command.isExcludedFromStats,
      isExcludedFromBudget: command.isExcludedFromBudget,
      voucher: const IncomeVoucher(),
      buildInput: (original) => IncomeVoucherInput(
        amount: command.amount,
        receiveAccountId: command.receiveAccountId,
        incomeAccountId: command.incomeAccountId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        isExcludedFromStats:
            command.isExcludedFromStats ??
                original.transaction.isExcludedFromStats,
        isExcludedFromBudget:
            command.isExcludedFromBudget ??
                original.transaction.isExcludedFromBudget,
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctTransfer(
    CorrectTransferCommand command,
  ) {
    return _runCorrection(
      transactionId: command.transactionId,
      expectedPurpose: BusinessPurpose.transfer,
      note: command.note,
      isExcludedFromStats: command.isExcludedFromStats,
      isExcludedFromBudget: command.isExcludedFromBudget,
      voucher: const TransferVoucher(),
      buildInput: (original) => TransferVoucherInput(
        amount: command.amount,
        fromAccountId: command.fromAccountId,
        toAccountId: command.toAccountId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        isExcludedFromStats:
            command.isExcludedFromStats ??
                original.transaction.isExcludedFromStats,
        isExcludedFromBudget:
            command.isExcludedFromBudget ??
                original.transaction.isExcludedFromBudget,
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctReimbursementAdvance(
    CorrectReimbursementAdvanceCommand command,
  ) {
    return _runCorrection(
      transactionId: command.transactionId,
      expectedPurpose: BusinessPurpose.reimbursementAdvance,
      note: command.note,
      isExcludedFromStats: command.isExcludedFromStats,
      isExcludedFromBudget: command.isExcludedFromBudget,
      voucher: const ReimbursementAdvanceVoucher(),
      buildInput: (original) => ReimbursementAdvanceVoucherInput(
        amount: command.amount,
        receivableAccountId: command.receivableAccountId,
        paidFromAccountId: command.paidFromAccountId,
        expenseCategoryId: command.expenseCategoryId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        isExcludedFromStats:
            command.isExcludedFromStats ??
                original.transaction.isExcludedFromStats,
        isExcludedFromBudget:
            command.isExcludedFromBudget ??
                original.transaction.isExcludedFromBudget,
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctRefund(
    CorrectRefundCommand command,
  ) {
    return _runCorrection(
      transactionId: command.transactionId,
      expectedPurpose: BusinessPurpose.refund,
      note: command.note,
      isExcludedFromStats: command.isExcludedFromStats,
      isExcludedFromBudget: command.isExcludedFromBudget,
      voucher: const RefundVoucher(),
      buildInput: (original) => RefundVoucherInput(
        amount: command.amount,
        parentTransactionId: original.transaction.parentTransactionId,
        refundToAccountId: command.refundToAccountId,
        occurredAt: command.occurredAt,
        selfPrimaryAddback: original.transaction.primaryAmount,
        counterpartyName: command.counterpartyName,
        note: command.note,
        isExcludedFromStats:
            command.isExcludedFromStats ??
                original.transaction.isExcludedFromStats,
        isExcludedFromBudget:
            command.isExcludedFromBudget ??
                original.transaction.isExcludedFromBudget,
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctReimbursementReceipt(
    CorrectReimbursementReceiptCommand command,
  ) {
    return _runCorrection(
      transactionId: command.transactionId,
      expectedPurpose: BusinessPurpose.reimbursementReceipt,
      note: command.note,
      isExcludedFromStats: command.isExcludedFromStats,
      isExcludedFromBudget: command.isExcludedFromBudget,
      voucher: const ReimbursementReceiptVoucher(),
      buildInput: (original) => ReimbursementReceiptVoucherInput(
        amount: command.amount,
        advanceTransactionId: original.transaction.parentTransactionId ??
            original.transaction.rootTransactionId,
        receivableAccountId: command.receivableAccountId,
        receiveAccountId: command.receiveAccountId,
        occurredAt: command.occurredAt,
        selfPrimaryAddback: original.transaction.primaryAmount,
        counterpartyName: command.counterpartyName,
        note: command.note,
        isExcludedFromStats:
            command.isExcludedFromStats ??
                original.transaction.isExcludedFromStats,
        isExcludedFromBudget:
            command.isExcludedFromBudget ??
                original.transaction.isExcludedFromBudget,
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctReimbursementClose(
    CorrectReimbursementCloseCommand command,
  ) {
    return _runCorrection(
      transactionId: command.transactionId,
      expectedPurpose: BusinessPurpose.reimbursementClose,
      note: command.note,
      isExcludedFromStats: command.isExcludedFromStats,
      isExcludedFromBudget: command.isExcludedFromBudget,
      voucher: const ReimbursementCloseVoucher(),
      buildInput: (original) => ReimbursementCloseVoucherInput(
        actualReceivedAmount: command.actualReceivedAmount,
        advanceTransactionId: original.transaction.parentTransactionId ??
            original.transaction.rootTransactionId,
        receivableAccountId: command.receivableAccountId,
        receiveAccountId: command.receiveAccountId,
        occurredAt: command.occurredAt,
        outstandingOverride: _detailAmount(
          original,
          TransactionDetailType.reimbursementCloseMain,
        ),
        counterpartyName: command.counterpartyName,
        note: command.note,
        isExcludedFromStats:
            command.isExcludedFromStats ??
                original.transaction.isExcludedFromStats,
        isExcludedFromBudget:
            command.isExcludedFromBudget ??
                original.transaction.isExcludedFromBudget,
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctBorrowing(
    CorrectBorrowingCommand command,
  ) {
    return _runCorrection(
      transactionId: command.transactionId,
      expectedPurpose: BusinessPurpose.borrowing,
      note: command.note,
      isExcludedFromStats: command.isExcludedFromStats,
      isExcludedFromBudget: command.isExcludedFromBudget,
      voucher: const BorrowingVoucher(),
      buildInput: (original) => BorrowingVoucherInput(
        amount: command.amount,
        liabilityAccountId: command.liabilityAccountId,
        receiveAccountId: command.receiveAccountId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        ownership: original.transaction.ownership,
        isExcludedFromStats:
            command.isExcludedFromStats ??
                original.transaction.isExcludedFromStats,
        isExcludedFromBudget:
            command.isExcludedFromBudget ??
                original.transaction.isExcludedFromBudget,
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctRepayment(
    CorrectRepaymentCommand command,
  ) {
    return _runCorrection(
      transactionId: command.transactionId,
      expectedPurpose: BusinessPurpose.debtRepayment,
      note: command.note,
      isExcludedFromStats: command.isExcludedFromStats,
      isExcludedFromBudget: command.isExcludedFromBudget,
      voucher: const RepaymentVoucher(),
      buildInput: (original) => RepaymentVoucherInput(
        principal: command.principal,
        interest: command.interest,
        fee: command.fee,
        discount: command.discount,
        liabilityAccountId: command.liabilityAccountId,
        paidFromAccountId: command.paidFromAccountId,
        interestExpenseAccountId: command.interestExpenseAccountId,
        feeExpenseAccountId: command.feeExpenseAccountId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        ownership: original.transaction.ownership,
        isExcludedFromStats:
            command.isExcludedFromStats ??
                original.transaction.isExcludedFromStats,
        isExcludedFromBudget:
            command.isExcludedFromBudget ??
                original.transaction.isExcludedFromBudget,
      ),
    );
  }

  Future<Result<CreatedTransactionResult>> _runCorrection<I>({
    required int transactionId,
    required BusinessPurpose expectedPurpose,
    required String? note,
    required bool? isExcludedFromStats,
    required bool? isExcludedFromBudget,
    required TransactionVoucher<I> voucher,
    required I Function(TransactionDetail original) buildInput,
  }) async {
    final original = await _queryService
        .watchTransactionDetail(transactionId)
        .first;
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
    if (original.transaction.businessPurpose != expectedPurpose) {
      return const Result.failure(
        Failure(
          code: 'transaction_correction_purpose_mismatch',
          message: 'Correction command purpose must match the transaction.',
        ),
      );
    }

    final input = buildInput(original);

    if (original.children.isNotEmpty) {
      final replacementBuild = await voucher.build(input, _voucherContext);
      switch (replacementBuild) {
        case FailureResult(:final failure):
          return Result.failure(failure);
        case Success(:final value):
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
    }

    return _runner.runReplacement(
      voucher: voucher,
      input: input,
      original: original,
    );
  }

  @override
  Future<Result<void>> deleteTransaction(
    DeleteTransactionCommand command,
  ) async {
    final query = _queryService;
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

    final detailsToCancel = <TransactionDetail>[];
    for (final child in target.children) {
      final childDetail = await query.watchTransactionDetail(child.id).first;
      if (childDetail != null &&
          childDetail.transaction.businessState == BusinessState.current) {
        detailsToCancel.add(childDetail);
      }
    }
    detailsToCancel.add(target);

    return _runner.runCancellation(details: detailsToCancel);
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
    final transaction = await _queryService.findTransactionById(
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

    final query = _queryService;
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
    final accountTypes = await _loadAccountTypes(
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
    final transaction = await _queryService.findTransactionById(
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
      final settlementType =
          accountType == AccountType.asset ||
          accountType == AccountType.liability;
      final isReimbursementReceivable =
          detail.transaction.businessPurpose ==
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

  Future<Map<int, AccountType>> _loadAccountTypes(
    Iterable<int> accountIds,
  ) async {
    final ids = accountIds.toSet();
    if (ids.isEmpty) return const {};
    final accounts = await _accountRepository.findAccountsByIds(ids);
    return {for (final account in accounts) account.id: account.type};
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
