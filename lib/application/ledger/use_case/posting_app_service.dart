import '../../../core/error/failure.dart';
import '../../../core/id/id_generator.dart';
import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../../../core/result/result.dart';
import '../../../application/shared/transaction_runner.dart';
import '../command/transaction_command.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/port/root_transaction_group_repository.dart';
import 'package:smartflow/domain/ledger/port/system_account_resolver.dart';
import 'package:smartflow/domain/ledger/port/transaction_repository.dart';
import 'package:smartflow/domain/ledger/service/account_posting_service.dart';
import 'package:smartflow/domain/ledger/service/account_role_policy.dart';
import 'package:smartflow/domain/ledger/service/child_transaction_migration_policy.dart';
import 'package:smartflow/domain/ledger/service/entry_reassignment_service.dart';
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

class PostingAppServiceImpl implements PostingAppService {
  PostingAppServiceImpl({
    required TransactionQueryService transactionQueryService,
    required AccountRepository accountRepository,
    required TransactionRepository transactionRepository,
    required RootTransactionGroupRepository rootGroupRepository,
    required SystemAccountResolver systemAccountResolver,
    required TransactionRunner transactionRunner,
    required IdGenerator idGenerator,
    EntryReassignmentService reassignmentService =
        const EntryReassignmentService(),
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
             accountRepository: accountRepository,
             accountRolePolicy:
                 accountRolePolicy ??
                 AccountRolePolicy(accountRepository: accountRepository),
             reassignmentService: reassignmentService,
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
  Future<Result<CreatedTransactionResult>> createExpense(
    CreateExpenseCommand command,
  ) async {
    final postingResult = await _ledgerPostingService.postExpense(
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
    );
    if (postingResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final posting = postingResult.value;
    return _transactionRunner.run(() async {
      await _transactionRepository.save(posting.transaction);
      await _accountRepository.saveAll(posting.accounts);
      return Result.success(
        CreatedTransactionResult(
          transactionId: posting.transaction.id,
          rootTransactionId: posting.transaction.rootTransactionId,
        ),
      );
    });
  }

  @override
  Future<Result<CreatedTransactionResult>> createIncome(
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
  Future<Result<CreatedTransactionResult>> createTransfer(
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
  Future<Result<CreatedTransactionResult>> createRefund(
    CreateRefundCommand command,
  ) async {
    final postingResult = await _refundPostingService.postRefund(
      RefundInstruction(
        parentTransactionId: command.parentTransactionId,
        amount: command.amount,
        refundToAccountId: command.refundToAccountId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
      ),
    );
    if (postingResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final posting = postingResult.value;
    return _transactionRunner.run(() async {
      await _transactionRepository.save(posting.transaction);
      await _accountRepository.saveAll(posting.accounts);
      return Result.success(
        CreatedTransactionResult(
          transactionId: posting.transaction.id,
          rootTransactionId: posting.transaction.rootTransactionId,
        ),
      );
    });
  }

  @override
  Future<Result<CreatedTransactionResult>> createReimbursementAdvance(
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
  Future<Result<CreatedTransactionResult>> createReimbursementReceipt(
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
  Future<Result<CreatedTransactionResult>> closeReimbursement(
    CloseReimbursementCommand command,
  ) async {
    final postingResult = await _reimbursementPostingService.close(
      ReimbursementCloseInstruction(
        advanceTransactionId: command.advanceTransactionId,
        actualReceivedAmount: command.actualReceivedAmount,
        receivableAccountId: command.receivableAccountId,
        receiveAccountId: command.receiveAccountId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
      ),
    );
    if (postingResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final posting = postingResult.value;
    return _transactionRunner.run(() async {
      await _transactionRepository.save(posting.transaction);
      await _accountRepository.saveAll(posting.accounts);
      return Result.success(
        CreatedTransactionResult(
          transactionId: posting.transaction.id,
          rootTransactionId: posting.transaction.rootTransactionId,
        ),
      );
    });
  }

  @override
  Future<Result<CreatedTransactionResult>> createRepayment(
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
  Future<Result<CreatedTransactionResult>> createBorrowing(
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
  Future<Result<CreatedTransactionResult>> createOpeningBalance(
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
  Future<Result<CreatedTransactionResult>> adjustBalance(
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
  Future<Result<CreatedTransactionResult>> correctExpense(
    CorrectExpenseCommand cmd,
  ) async {
    return _persistParentReplacement(
      await _ledgerCorrectionService.replaceParentTransaction(
        ReplaceParentTransactionInstruction(
          transactionId: cmd.transactionId,
          expectedCurrentPurpose: BusinessPurpose.dailyExpense,
          replacementPatch: ExpenseReplacementPatch(
            amount: cmd.amount,
            paidFromAccountId: cmd.paidFromAccountId,
            expenseAccountId: cmd.expenseAccountId,
          ),
        ),
      ),
      occurredAt: cmd.occurredAt,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctIncome(
    CorrectIncomeCommand cmd,
  ) async {
    return _persistParentReplacement(
      await _ledgerCorrectionService.replaceParentTransaction(
        ReplaceParentTransactionInstruction(
          transactionId: cmd.transactionId,
          expectedCurrentPurpose: BusinessPurpose.dailyIncome,
          replacementPatch: IncomeReplacementPatch(
            amount: cmd.amount,
            receiveAccountId: cmd.receiveAccountId,
            incomeAccountId: cmd.incomeAccountId,
          ),
        ),
      ),
      occurredAt: cmd.occurredAt,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctTransfer(
    CorrectTransferCommand cmd,
  ) async {
    return _persistParentReplacement(
      await _ledgerCorrectionService.replaceParentTransaction(
        ReplaceParentTransactionInstruction(
          transactionId: cmd.transactionId,
          expectedCurrentPurpose: BusinessPurpose.transfer,
          replacementPatch: TransferReplacementPatch(
            amount: cmd.amount,
            fromAccountId: cmd.fromAccountId,
            toAccountId: cmd.toAccountId,
            feeAmount: Money.zero(),
            feeExpenseAccountId: const Patch<String?>.set(null),
          ),
        ),
      ),
      occurredAt: cmd.occurredAt,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctReimbursementAdvance(
    CorrectReimbursementAdvanceCommand cmd,
  ) async {
    return _persistParentReplacement(
      await _ledgerCorrectionService.replaceParentTransaction(
        ReplaceParentTransactionInstruction(
          transactionId: cmd.transactionId,
          expectedCurrentPurpose: BusinessPurpose.reimbursementAdvance,
          replacementPatch: ReimbursementAdvanceReplacementPatch(
            amount: cmd.amount,
            receivableAccountId: cmd.receivableAccountId,
            paidFromAccountId: cmd.paidFromAccountId,
            expenseAccountId: cmd.expenseCategoryId,
          ),
        ),
      ),
      occurredAt: cmd.occurredAt,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctRefund(
    CorrectRefundCommand cmd,
  ) async {
    return _persistChildReplacement(
      await _ledgerCorrectionService.replaceRefundTransaction(
        ReplaceRefundTransactionInstruction(
          transactionId: cmd.transactionId,
          replacementPatch: RefundReplacementPatch(
            amount: cmd.amount,
            refundToAccountId: cmd.refundToAccountId,
          ),
        ),
      ),
      occurredAt: cmd.occurredAt,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctReimbursementReceipt(
    CorrectReimbursementReceiptCommand cmd,
  ) async {
    return _persistChildReplacement(
      await _ledgerCorrectionService.replaceReimbursementReceipt(
        ReplaceReimbursementReceiptTransactionInstruction(
          transactionId: cmd.transactionId,
          amount: cmd.amount,
          receivableAccountId: cmd.receivableAccountId,
          receiveAccountId: cmd.receiveAccountId,
        ),
      ),
      occurredAt: cmd.occurredAt,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctReimbursementClose(
    CorrectReimbursementCloseCommand cmd,
  ) async {
    return _persistChildReplacement(
      await _ledgerCorrectionService.replaceReimbursementClose(
        ReplaceReimbursementCloseTransactionInstruction(
          transactionId: cmd.transactionId,
          actualReceivedAmount: cmd.actualReceivedAmount,
          receivableAccountId: cmd.receivableAccountId,
          receiveAccountId: cmd.receiveAccountId,
        ),
      ),
      occurredAt: cmd.occurredAt,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctBorrowing(
    CorrectBorrowingCommand cmd,
  ) async {
    return _persistParentReplacement(
      await _ledgerCorrectionService.replaceParentTransaction(
        ReplaceParentTransactionInstruction(
          transactionId: cmd.transactionId,
          expectedCurrentPurpose: BusinessPurpose.borrowing,
          replacementPatch: BorrowingReplacementPatch(
            amount: cmd.amount,
            liabilityAccountId: cmd.liabilityAccountId,
            receiveAccountId: cmd.receiveAccountId,
          ),
        ),
      ),
      occurredAt: cmd.occurredAt,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctRepayment(
    CorrectRepaymentCommand cmd,
  ) async {
    return _persistParentReplacement(
      await _ledgerCorrectionService.replaceParentTransaction(
        ReplaceParentTransactionInstruction(
          transactionId: cmd.transactionId,
          expectedCurrentPurpose: BusinessPurpose.debtRepayment,
          replacementPatch: RepaymentReplacementPatch(
            principal: cmd.principal,
            interest: Patch<Money?>.set(cmd.interest),
            fee: Patch<Money?>.set(cmd.fee),
            discount: Patch<Money?>.set(cmd.discount),
            liabilityAccountId: cmd.liabilityAccountId,
            paidFromAccountId: cmd.paidFromAccountId,
          ),
        ),
      ),
      occurredAt: cmd.occurredAt,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
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
  Future<Result<void>> updateTransactionMetadata(
    UpdateTransactionMetadataCommand command,
  ) async {
    return _persistTransactionUpdate(
      await _ledgerUpdateService.updateMetadata(
        UpdateTransactionMetadataInstruction(
          transactionId: command.transactionId,
          note: command.note,
          isExcludedFromStats: command.isExcludedFromStats,
          isExcludedFromBudget: command.isExcludedFromBudget,
        ),
      ),
      failureCode: 'transaction_metadata_update_failed',
      failureMessage: 'Failed to update transaction metadata.',
    );
  }

  @override
  Future<Result<void>> updateTransactionBasics(
    UpdateTransactionBasicsCommand command,
  ) async {
    return _persistTransactionUpdate(
      await _ledgerUpdateService.updateBasics(
        UpdateTransactionBasicsInstruction(
          transactionId: command.transactionId,
          occurredAt: command.occurredAt,
          settlementAccountId: command.settlementAccountId,
          reimbursementAccountId: command.reimbursementAccountId,
        ),
      ),
      failureCode: 'transaction_basics_update_failed',
      failureMessage: 'Failed to update transaction basics.',
    );
  }

  @override
  Future<Result<void>> updateTransactionOwnership(
    UpdateTransactionOwnershipCommand command,
  ) async {
    return _persistTransactionUpdate(
      await _ledgerUpdateService.updateOwnership(
        UpdateTransactionOwnershipInstruction(
          transactionId: command.transactionId,
          ownership: command.ownership,
        ),
      ),
      failureCode: 'transaction_ownership_update_failed',
      failureMessage: 'Failed to update transaction ownership.',
    );
  }

  Future<Result<CreatedTransactionResult>> _persistPosting(
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
        CreatedTransactionResult(
          transactionId: posting.transaction.id,
          rootTransactionId: posting.transaction.rootTransactionId,
        ),
      );
    });
  }

  Future<Result<CreatedTransactionResult>> _persistParentReplacement(
    Result<ParentReplacementResult> replacementResult, {
    required DateTime occurredAt,
    required String? counterpartyName,
    required String? note,
    required bool? isExcludedFromStats,
    required bool? isExcludedFromBudget,
  }) async {
    if (replacementResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final mutation = replacementResult.value;
    final group = mutation.currentGroup;
    group.parentTransaction.updateBasicInfo(
      occurredAt: occurredAt,
      counterpartyName: Patch<String?>.set(counterpartyName),
      note: Patch<String?>.set(note),
    );
    group.updateReportingFlags(
      isExcludedFromStats: isExcludedFromStats,
      isExcludedFromBudget: isExcludedFromBudget,
    );
    return _transactionRunner.run(() async {
      await _transactionRepository.saveAll(mutation.transactions);
      await _accountRepository.saveAll(mutation.accounts);
      return Result.success(
        CreatedTransactionResult(
          transactionId: group.parentTransaction.id,
          rootTransactionId: group.rootTransactionId,
        ),
      );
    });
  }

  Future<Result<CreatedTransactionResult>> _persistChildReplacement(
    Result<ChildReplacementResult> replacementResult, {
    required DateTime occurredAt,
    required String? counterpartyName,
    required String? note,
  }) async {
    if (replacementResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final mutation = replacementResult.value;
    final transaction = mutation.currentTransaction;
    transaction.updateBasicInfo(
      occurredAt: occurredAt,
      counterpartyName: Patch<String?>.set(counterpartyName),
      note: Patch<String?>.set(note),
    );
    return _transactionRunner.run(() async {
      await _transactionRepository.saveAll(mutation.transactions);
      await _accountRepository.saveAll(mutation.accounts);
      return Result.success(
        CreatedTransactionResult(
          transactionId: transaction.id,
          rootTransactionId: transaction.rootTransactionId,
        ),
      );
    });
  }

  Future<Result<void>> _persistTransactionUpdate(
    Result<TransactionUpdateResult> updateResult, {
    required String failureCode,
    required String failureMessage,
  }) async {
    if (updateResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final update = updateResult.value;
    return _transactionRunner.run(() async {
      try {
        await _transactionRepository.saveAll(update.transactions);
        await _accountRepository.saveAll(update.accounts);
        return const Result.success(null);
      } on Object catch (error) {
        return Result.failure(
          Failure(code: failureCode, message: failureMessage, cause: error),
        );
      }
    });
  }
}
