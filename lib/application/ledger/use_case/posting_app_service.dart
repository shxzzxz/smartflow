import '../../../core/id/id_generator.dart';
import '../../../core/result/result.dart';
import '../../../application/shared/transaction_runner.dart';
import '../command/transaction_command.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/port/root_transaction_group_repository.dart';
import 'package:smartflow/domain/ledger/port/system_account_resolver.dart';
import 'package:smartflow/domain/ledger/port/transaction_repository.dart';
import 'package:smartflow/domain/ledger/service/account_posting_service.dart';
import 'package:smartflow/domain/ledger/service/account_role_policy.dart';
import 'package:smartflow/domain/ledger/service/child_transaction_migration_policy.dart';
import 'package:smartflow/domain/ledger/service/ledger_correction_service.dart';
import 'package:smartflow/domain/ledger/service/ledger_posting_service.dart';
import 'package:smartflow/domain/ledger/service/ledger_update_service.dart';
import 'package:smartflow/domain/ledger/service/posting_engine.dart';
import 'package:smartflow/domain/ledger/service/posting_instruction_resolver.dart';
import 'package:smartflow/domain/ledger/service/refund_posting_service.dart';
import 'package:smartflow/domain/ledger/service/reimbursement_posting_service.dart';
import 'package:smartflow/domain/ledger/valobj/posting_instruction.dart';
import 'package:smartflow/domain/ledger/valobj/posting_result.dart';
import '../query/transaction_query_service.dart';

abstract interface class PostingAppService {
  Future<Result<PostedTransactionResult>> createExpense(
    CreateExpenseCommand command,
  );

  Future<Result<PostedTransactionResult>> createIncome(
    CreateIncomeCommand command,
  );

  Future<Result<PostedTransactionResult>> createTransfer(
    CreateTransferCommand command,
  );

  Future<Result<PostedTransactionResult>> createRefund(
    CreateRefundCommand command,
  );

  Future<Result<PostedTransactionResult>> createReimbursementAdvance(
    CreateReimbursementAdvanceCommand command,
  );

  Future<Result<PostedTransactionResult>> createReimbursementReceipt(
    CreateReimbursementReceiptCommand command,
  );

  Future<Result<PostedTransactionResult>> closeReimbursement(
    CloseReimbursementCommand command,
  );

  Future<Result<PostedTransactionResult>> createRepayment(
    CreateRepaymentCommand command,
  );

  Future<Result<PostedTransactionResult>> createBorrowing(
    CreateBorrowingCommand command,
  );

  Future<Result<PostedTransactionResult>> createOpeningBalance(
    CreateOpeningBalanceCommand command,
  );

  Future<Result<PostedTransactionResult>> adjustBalance(
    AdjustBalanceCommand command,
  );

  Future<Result<PostedTransactionResult>> correctExpense(
    CorrectExpenseCommand command,
  );

  Future<Result<PostedTransactionResult>> correctIncome(
    CorrectIncomeCommand command,
  );

  Future<Result<PostedTransactionResult>> correctTransfer(
    CorrectTransferCommand command,
  );

  Future<Result<PostedTransactionResult>> correctReimbursementAdvance(
    CorrectReimbursementAdvanceCommand command,
  );

  Future<Result<PostedTransactionResult>> correctRefund(
    CorrectRefundCommand command,
  );

  Future<Result<PostedTransactionResult>> correctReimbursementReceipt(
    CorrectReimbursementReceiptCommand command,
  );

  Future<Result<PostedTransactionResult>> correctReimbursementClose(
    CorrectReimbursementCloseCommand command,
  );

  Future<Result<PostedTransactionResult>> correctBorrowing(
    CorrectBorrowingCommand command,
  );

  Future<Result<PostedTransactionResult>> correctRepayment(
    CorrectRepaymentCommand command,
  );

  Future<Result<void>> deleteTransaction(DeleteTransactionCommand command);

  Future<Result<PostedTransactionResult>> updateBasicInfo(
    UpdateTransactionBasicInfoCommand command,
  );

  Future<Result<PostedTransactionResult>> updateReportingFlag(
    UpdateTransactionReportingFlagCommand command,
  );

  Future<Result<PostedTransactionResult>> updateOwnership(
    UpdateTransactionOwnershipCommand command,
  );
}

class PostingAppServiceImpl implements PostingAppService {
  PostingAppServiceImpl({
    required TransactionQueryService transactionQueryService,
    required AccountRepository accountRepository,
    required TransactionRepository transactionRepository,
    required RootTransactionGroupRepository rootGroupRepository,
    required SystemAccountResolver systemAccountResolver,
    required TransactionRunner transactionRunner,
    required IdGenerator idGenerator,
    AccountRolePolicy? accountRolePolicy,
    PostingEngine? postingEngine,
    PostingInstructionResolver? postingInstructionResolver,
    AccountPostingService accountPostingService =
        const DefaultAccountPostingService(),
    LedgerPostingService? ledgerPostingService,
    RefundPostingService? refundPostingService,
    ReimbursementPostingService? reimbursementPostingService,
    LedgerCorrectionService? ledgerCorrectionService,
    LedgerUpdateService? ledgerUpdateService,
  }) : _accountRepository = accountRepository,
       _transactionRepository = transactionRepository,
       _transactionRunner = transactionRunner,
       _ledgerPostingService =
           ledgerPostingService ??
           LedgerPostingService(
             accountRepository: accountRepository,
             systemAccountResolver: systemAccountResolver,
             postingEngine:
                 postingEngine ?? PostingEngine(idGenerator: idGenerator),
             accountPostingService: accountPostingService,
             accountRolePolicy:
                 accountRolePolicy ??
                 AccountRolePolicy(accountRepository: accountRepository),
           ),
       _refundPostingService =
           refundPostingService ??
           RefundPostingService(
             rootGroupRepository: rootGroupRepository,
             accountRepository: accountRepository,
             postingInstructionResolver:
                 postingInstructionResolver ??
                 const DefaultPostingInstructionResolver(),
             postingEngine:
                 postingEngine ?? PostingEngine(idGenerator: idGenerator),
             accountPostingService: accountPostingService,
             accountRolePolicy:
                 accountRolePolicy ??
                 AccountRolePolicy(accountRepository: accountRepository),
           ),
       _reimbursementPostingService =
           reimbursementPostingService ??
           ReimbursementPostingService(
             rootGroupRepository: rootGroupRepository,
             accountRepository: accountRepository,
             systemAccountResolver: systemAccountResolver,
             postingEngine:
                 postingEngine ?? PostingEngine(idGenerator: idGenerator),
             accountPostingService: accountPostingService,
             accountRolePolicy:
                 accountRolePolicy ??
                 AccountRolePolicy(accountRepository: accountRepository),
           ),
       _ledgerCorrectionService =
           ledgerCorrectionService ??
           LedgerCorrectionService(
             rootGroupRepository: rootGroupRepository,
             accountRepository: accountRepository,
             postingInstructionResolver:
                 postingInstructionResolver ??
                 const DefaultPostingInstructionResolver(),
             postingEngine:
                 postingEngine ?? PostingEngine(idGenerator: idGenerator),
             accountPostingService: accountPostingService,
             accountRolePolicy:
                 accountRolePolicy ??
                 AccountRolePolicy(accountRepository: accountRepository),
             systemAccountResolver: systemAccountResolver,
             childMigrationPolicy: RefundOnlyChildMigrationPolicy(
               postingEngine:
                   postingEngine ?? PostingEngine(idGenerator: idGenerator),
               postingInstructionResolver:
                   postingInstructionResolver ??
                   const DefaultPostingInstructionResolver(),
             ),
           ),
       _ledgerUpdateService =
           ledgerUpdateService ??
           LedgerUpdateService(
             transactionRepository: transactionRepository,
             rootGroupRepository: rootGroupRepository,
           );

  final AccountRepository _accountRepository;
  final TransactionRepository _transactionRepository;
  final TransactionRunner _transactionRunner;
  final LedgerPostingService _ledgerPostingService;
  final RefundPostingService _refundPostingService;
  final ReimbursementPostingService _reimbursementPostingService;
  final LedgerCorrectionService _ledgerCorrectionService;
  final LedgerUpdateService _ledgerUpdateService;

  @override
  Future<Result<PostedTransactionResult>> createExpense(
    CreateExpenseCommand command,
  ) async {
    return _persistPosting(
      await _ledgerPostingService.postExpense(
        ExpenseInstruction(
          amount: command.amount,
          paidFromAccountId: command.paidFromAccountId,
          expenseAccountId: command.expenseAccountId,
          occurredAt: command.occurredAt,
          counterpartyName: command.counterpartyName,
          note: command.note,
          isExcludedFromStats: command.isExcludedFromStats,
          isExcludedFromBudget: command.isExcludedFromBudget,
        ),
      ),
    );
  }

  @override
  Future<Result<PostedTransactionResult>> createIncome(
    CreateIncomeCommand command,
  ) async {
    return _persistPosting(
      await _ledgerPostingService.postIncome(
        IncomeInstruction(
          amount: command.amount,
          receiveAccountId: command.receiveAccountId,
          incomeAccountId: command.incomeAccountId,
          occurredAt: command.occurredAt,
          counterpartyName: command.counterpartyName,
          note: command.note,
          isExcludedFromStats: command.isExcludedFromStats,
        ),
      ),
    );
  }

  @override
  Future<Result<PostedTransactionResult>> createTransfer(
    CreateTransferCommand command,
  ) async {
    return _persistPosting(
      await _ledgerPostingService.postTransfer(
        TransferInstruction(
          amount: command.amount,
          fromAccountId: command.fromAccountId,
          toAccountId: command.toAccountId,
          occurredAt: command.occurredAt,
          feeAmount: command.feeAmount,
          feeExpenseAccountId: command.feeExpenseAccountId,
          counterpartyName: command.counterpartyName,
          note: command.note,
        ),
      ),
    );
  }

  @override
  Future<Result<PostedTransactionResult>> createRefund(
    CreateRefundCommand command,
  ) async {
    return _persistPosting(
      await _refundPostingService.postRefund(
        RefundInstruction(
          parentTransactionId: command.parentTransactionId,
          amount: command.amount,
          refundToAccountId: command.refundToAccountId,
          occurredAt: command.occurredAt,
          counterpartyName: command.counterpartyName,
          note: command.note,
        ),
      ),
    );
  }

  @override
  Future<Result<PostedTransactionResult>> createReimbursementAdvance(
    CreateReimbursementAdvanceCommand command,
  ) async {
    return _persistPosting(
      await _reimbursementPostingService.postAdvance(
        ReimbursementAdvanceInstruction(
          amount: command.amount,
          receivableAccountId: command.receivableAccountId,
          paidFromAccountId: command.paidFromAccountId,
          expenseAccountId: command.expenseCategoryId,
          occurredAt: command.occurredAt,
          counterpartyName: command.counterpartyName,
          note: command.note,
        ),
      ),
    );
  }

  @override
  Future<Result<PostedTransactionResult>> createReimbursementReceipt(
    CreateReimbursementReceiptCommand command,
  ) async {
    return _persistPosting(
      await _reimbursementPostingService.postReceipt(
        ReimbursementReceiptInstruction(
          advanceTransactionId: command.advanceTransactionId,
          amount: command.amount,
          receivableAccountId: command.receivableAccountId,
          receiveAccountId: command.receiveAccountId,
          occurredAt: command.occurredAt,
          counterpartyName: command.counterpartyName,
          note: command.note,
        ),
      ),
    );
  }

  @override
  Future<Result<PostedTransactionResult>> closeReimbursement(
    CloseReimbursementCommand command,
  ) async {
    return _persistPosting(
      await _reimbursementPostingService.close(
        ReimbursementCloseInstruction(
          advanceTransactionId: command.advanceTransactionId,
          actualReceivedAmount: command.actualReceivedAmount,
          receivableAccountId: command.receivableAccountId,
          receiveAccountId: command.receiveAccountId,
          occurredAt: command.occurredAt,
          counterpartyName: command.counterpartyName,
          note: command.note,
        ),
      ),
    );
  }

  @override
  Future<Result<PostedTransactionResult>> createRepayment(
    CreateRepaymentCommand command,
  ) async {
    return _persistPosting(
      await _ledgerPostingService.postRepayment(
        RepaymentInstruction(
          principal: command.principal,
          liabilityAccountId: command.liabilityAccountId,
          paidFromAccountId: command.paidFromAccountId,
          occurredAt: command.occurredAt,
          interest: command.interest,
          fee: command.fee,
          discount: command.discount,
          counterpartyName: command.counterpartyName,
          note: command.note,
          ownership: command.ownership,
        ),
      ),
    );
  }

  @override
  Future<Result<PostedTransactionResult>> createBorrowing(
    CreateBorrowingCommand command,
  ) async {
    return _persistPosting(
      await _ledgerPostingService.postBorrowing(
        BorrowingInstruction(
          amount: command.amount,
          liabilityAccountId: command.liabilityAccountId,
          receiveAccountId: command.receiveAccountId,
          occurredAt: command.occurredAt,
          counterpartyName: command.counterpartyName,
          note: command.note,
          ownership: command.ownership,
        ),
      ),
    );
  }

  @override
  Future<Result<PostedTransactionResult>> createOpeningBalance(
    CreateOpeningBalanceCommand command,
  ) async {
    return _persistPosting(
      await _ledgerPostingService.postOpeningBalance(
        OpeningBalanceInstruction(
          accountId: command.accountId,
          amount: command.amount,
          occurredAt: command.occurredAt,
          counterpartyName: command.counterpartyName,
          note: command.note,
        ),
      ),
    );
  }

  @override
  Future<Result<PostedTransactionResult>> adjustBalance(
    AdjustBalanceCommand command,
  ) async {
    return _persistPosting(
      await _ledgerPostingService.postBalanceAdjustment(
        BalanceAdjustmentInstruction(
          accountId: command.accountId,
          targetBalance: command.targetBalance,
          occurredAt: command.occurredAt,
          counterpartyName: command.counterpartyName,
          note: command.note,
        ),
      ),
    );
  }

  @override
  Future<Result<PostedTransactionResult>> correctExpense(
    CorrectExpenseCommand cmd,
  ) async {
    return _persistParentReplacement(
      await _ledgerCorrectionService.replaceParentTransaction(
        ReplaceParentTransactionInstruction(
          transactionId: cmd.transactionId,
          expectedCurrentPurpose: BusinessPurpose.dailyExpense,
          occurredAt: cmd.occurredAt,
          counterpartyName: cmd.counterpartyName,
          note: cmd.note,
          isExcludedFromStats: cmd.isExcludedFromStats,
          isExcludedFromBudget: cmd.isExcludedFromBudget,
          replacementPatch: ExpenseReplacementPatch(
            amount: cmd.amount,
            paidFromAccountId: cmd.paidFromAccountId,
            expenseAccountId: cmd.expenseAccountId,
          ),
        ),
      ),
    );
  }

  @override
  Future<Result<PostedTransactionResult>> correctIncome(
    CorrectIncomeCommand cmd,
  ) async {
    return _persistParentReplacement(
      await _ledgerCorrectionService.replaceParentTransaction(
        ReplaceParentTransactionInstruction(
          transactionId: cmd.transactionId,
          expectedCurrentPurpose: BusinessPurpose.dailyIncome,
          occurredAt: cmd.occurredAt,
          counterpartyName: cmd.counterpartyName,
          note: cmd.note,
          isExcludedFromStats: cmd.isExcludedFromStats,
          replacementPatch: IncomeReplacementPatch(
            amount: cmd.amount,
            receiveAccountId: cmd.receiveAccountId,
            incomeAccountId: cmd.incomeAccountId,
          ),
        ),
      ),
    );
  }

  @override
  Future<Result<PostedTransactionResult>> correctTransfer(
    CorrectTransferCommand cmd,
  ) async {
    return _persistParentReplacement(
      await _ledgerCorrectionService.replaceParentTransaction(
        ReplaceParentTransactionInstruction(
          transactionId: cmd.transactionId,
          expectedCurrentPurpose: BusinessPurpose.transfer,
          occurredAt: cmd.occurredAt,
          counterpartyName: cmd.counterpartyName,
          note: cmd.note,
          replacementPatch: TransferReplacementPatch(
            amount: cmd.amount,
            fromAccountId: cmd.fromAccountId,
            toAccountId: cmd.toAccountId,
            feeAmount: cmd.feeAmount,
            feeExpenseAccountId: cmd.feeExpenseAccountId,
          ),
        ),
      ),
    );
  }

  @override
  Future<Result<PostedTransactionResult>> correctReimbursementAdvance(
    CorrectReimbursementAdvanceCommand cmd,
  ) async {
    return _persistParentReplacement(
      await _ledgerCorrectionService.replaceParentTransaction(
        ReplaceParentTransactionInstruction(
          transactionId: cmd.transactionId,
          expectedCurrentPurpose: BusinessPurpose.reimbursementAdvance,
          occurredAt: cmd.occurredAt,
          counterpartyName: cmd.counterpartyName,
          note: cmd.note,
          isExcludedFromStats: cmd.isExcludedFromStats,
          isExcludedFromBudget: cmd.isExcludedFromBudget,
          replacementPatch: ReimbursementAdvanceReplacementPatch(
            amount: cmd.amount,
            receivableAccountId: cmd.receivableAccountId,
            paidFromAccountId: cmd.paidFromAccountId,
            expenseAccountId: cmd.expenseCategoryId,
          ),
        ),
      ),
    );
  }

  @override
  Future<Result<PostedTransactionResult>> correctRefund(
    CorrectRefundCommand cmd,
  ) async {
    return _persistChildReplacement(
      await _ledgerCorrectionService.replaceRefundTransaction(
        ReplaceRefundTransactionInstruction(
          transactionId: cmd.transactionId,
          occurredAt: cmd.occurredAt,
          counterpartyName: cmd.counterpartyName,
          note: cmd.note,
          replacementPatch: RefundReplacementPatch(
            amount: cmd.amount,
            refundToAccountId: cmd.refundToAccountId,
          ),
        ),
      ),
    );
  }

  @override
  Future<Result<PostedTransactionResult>> correctReimbursementReceipt(
    CorrectReimbursementReceiptCommand cmd,
  ) async {
    return _persistChildReplacement(
      await _ledgerCorrectionService.replaceReimbursementReceipt(
        ReplaceReimbursementReceiptTransactionInstruction(
          transactionId: cmd.transactionId,
          amount: cmd.amount,
          receivableAccountId: cmd.receivableAccountId,
          receiveAccountId: cmd.receiveAccountId,
          occurredAt: cmd.occurredAt,
          counterpartyName: cmd.counterpartyName,
          note: cmd.note,
        ),
      ),
    );
  }

  @override
  Future<Result<PostedTransactionResult>> correctReimbursementClose(
    CorrectReimbursementCloseCommand cmd,
  ) async {
    return _persistChildReplacement(
      await _ledgerCorrectionService.replaceReimbursementClose(
        ReplaceReimbursementCloseTransactionInstruction(
          transactionId: cmd.transactionId,
          actualReceivedAmount: cmd.actualReceivedAmount,
          receivableAccountId: cmd.receivableAccountId,
          receiveAccountId: cmd.receiveAccountId,
          occurredAt: cmd.occurredAt,
          counterpartyName: cmd.counterpartyName,
          note: cmd.note,
        ),
      ),
    );
  }

  @override
  Future<Result<PostedTransactionResult>> correctBorrowing(
    CorrectBorrowingCommand cmd,
  ) async {
    return _persistParentReplacement(
      await _ledgerCorrectionService.replaceParentTransaction(
        ReplaceParentTransactionInstruction(
          transactionId: cmd.transactionId,
          expectedCurrentPurpose: BusinessPurpose.borrowing,
          occurredAt: cmd.occurredAt,
          counterpartyName: cmd.counterpartyName,
          note: cmd.note,
          replacementPatch: BorrowingReplacementPatch(
            amount: cmd.amount,
            liabilityAccountId: cmd.liabilityAccountId,
            receiveAccountId: cmd.receiveAccountId,
          ),
        ),
      ),
    );
  }

  @override
  Future<Result<PostedTransactionResult>> correctRepayment(
    CorrectRepaymentCommand cmd,
  ) async {
    return _persistParentReplacement(
      await _ledgerCorrectionService.replaceParentTransaction(
        ReplaceParentTransactionInstruction(
          transactionId: cmd.transactionId,
          expectedCurrentPurpose: BusinessPurpose.debtRepayment,
          occurredAt: cmd.occurredAt,
          counterpartyName: cmd.counterpartyName,
          note: cmd.note,
          replacementPatch: RepaymentReplacementPatch(
            principal: cmd.principal,
            interest: cmd.interest,
            fee: cmd.fee,
            discount: cmd.discount,
            liabilityAccountId: cmd.liabilityAccountId,
            paidFromAccountId: cmd.paidFromAccountId,
          ),
        ),
      ),
    );
  }

  @override
  Future<Result<void>> deleteTransaction(
    DeleteTransactionCommand command,
  ) async {
    final cancellationResult = await _ledgerCorrectionService.cancelTransaction(
      CancelTransactionInstruction(transactionId: command.transactionId),
    );
    if (cancellationResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final cancellation = cancellationResult.value;
    return _transactionRunner.run(() async {
      await _transactionRepository.saveAll(cancellation.transactions);
      await _accountRepository.saveAll(cancellation.accounts);
      return const Result.success(null);
    });
  }

  @override
  Future<Result<PostedTransactionResult>> updateBasicInfo(
    UpdateTransactionBasicInfoCommand command,
  ) async {
    return _persistTransactionUpdate(
      await _ledgerUpdateService.updateBasicInfo(
        UpdateTransactionBasicInfoInstruction(
          transactionId: command.transactionId,
          occurredAt: command.occurredAt,
          counterpartyName: command.counterpartyName,
          note: command.note,
        ),
      ),
    );
  }

  @override
  Future<Result<PostedTransactionResult>> updateReportingFlag(
    UpdateTransactionReportingFlagCommand command,
  ) async {
    return _persistTransactionUpdate(
      await _ledgerUpdateService.updateReportingFlag(
        UpdateTransactionReportingFlagInstruction(
          transactionId: command.transactionId,
          isExcludedFromStats: command.isExcludedFromStats,
          isExcludedFromBudget: command.isExcludedFromBudget,
        ),
      ),
    );
  }

  @override
  Future<Result<PostedTransactionResult>> updateOwnership(
    UpdateTransactionOwnershipCommand command,
  ) async {
    return _persistTransactionUpdate(
      await _ledgerUpdateService.updateOwnership(
        UpdateTransactionOwnershipInstruction(
          transactionId: command.transactionId,
          ownership: command.ownership,
        ),
      ),
    );
  }

  Future<Result<PostedTransactionResult>> _persistPosting(
    Result<PostingResult> postingResult,
  ) async {
    if (postingResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final posting = postingResult.value;
    return _transactionRunner.run(() async {
      await _transactionRepository.save(posting.transaction);
      await _accountRepository.saveAll(posting.accounts);
      return Result.success(
        PostedTransactionResult(
          transactionId: posting.transaction.id,
          rootTransactionId: posting.transaction.rootTransactionId,
        ),
      );
    });
  }

  Future<Result<PostedTransactionResult>> _persistParentReplacement(
    Result<ParentReplacementResult> replacementResult,
  ) async {
    if (replacementResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final mutation = replacementResult.value;
    return _persistLedgerWrite(
      transactions: mutation.transactions,
      accounts: mutation.accounts,
      currentTransaction: mutation.currentTransaction,
    );
  }

  Future<Result<PostedTransactionResult>> _persistChildReplacement(
    Result<ChildReplacementResult> replacementResult,
  ) async {
    if (replacementResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final mutation = replacementResult.value;
    return _persistLedgerWrite(
      transactions: mutation.transactions,
      accounts: mutation.accounts,
      currentTransaction: mutation.currentTransaction,
    );
  }

  Future<Result<PostedTransactionResult>> _persistTransactionUpdate(
    Result<TransactionUpdateResult> updateResult,
  ) async {
    if (updateResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final update = updateResult.value;
    return _persistLedgerWrite(
      transactions: update.transactions,
      accounts: update.accounts,
      currentTransaction: update.currentTransaction,
    );
  }

  Future<Result<PostedTransactionResult>> _persistLedgerWrite({
    required Iterable<Transaction> transactions,
    required Iterable<Account> accounts,
    required Transaction currentTransaction,
  }) async {
    return _transactionRunner.run(() async {
      await _transactionRepository.saveAll(transactions);
      await _accountRepository.saveAll(accounts);
      return Result.success(
        PostedTransactionResult(
          transactionId: currentTransaction.id,
          rootTransactionId: currentTransaction.rootTransactionId,
        ),
      );
    });
  }
}
