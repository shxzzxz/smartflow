import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/port/root_transaction_group_repository.dart';
import 'package:smartflow/domain/ledger/port/system_account_resolver.dart';
import 'package:smartflow/domain/ledger/service/account/account_role_policy.dart';
import 'package:smartflow/domain/ledger/service/mutation/child_transaction_migration_policy.dart';
import 'package:smartflow/domain/ledger/service/mutation/ledger_correction_service.dart';
import 'package:smartflow/domain/ledger/service/posting/account_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_instruction_resolver.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/posting_instruction.dart';

import 'transaction_command.dart';
import 'transaction_ledger_writer.dart';

abstract interface class TransactionCorrectionAppService {
  Future<PostedTransactionResult> correctExpense(CorrectExpenseCommand command);

  Future<PostedTransactionResult> correctIncome(CorrectIncomeCommand command);

  Future<PostedTransactionResult> correctTransfer(
    CorrectTransferCommand command,
  );

  Future<PostedTransactionResult> correctReimbursementAdvance(
    CorrectReimbursementAdvanceCommand command,
  );

  Future<PostedTransactionResult> correctRefund(CorrectRefundCommand command);

  Future<PostedTransactionResult> correctReimbursementReceipt(
    CorrectReimbursementReceiptCommand command,
  );

  Future<PostedTransactionResult> correctReimbursementClose(
    CorrectReimbursementCloseCommand command,
  );

  Future<PostedTransactionResult> correctBorrowing(
    CorrectBorrowingCommand command,
  );

  Future<PostedTransactionResult> correctRepayment(
    CorrectRepaymentCommand command,
  );

  Future<void> deleteTransaction(DeleteTransactionCommand command);
}

class TransactionCorrectionAppServiceImpl
    implements TransactionCorrectionAppService {
  TransactionCorrectionAppServiceImpl({
    required AccountRepository accountRepository,
    required RootTransactionGroupRepository rootGroupRepository,
    required SystemAccountResolver systemAccountResolver,
    required TransactionLedgerWriter ledgerWriter,
    required IdGenerator idGenerator,
    AccountRolePolicy? accountRolePolicy,
    PostingEngine? postingEngine,
    PostingInstructionResolver? postingInstructionResolver,
    AccountPostingService accountPostingService =
        const DefaultAccountPostingService(),
    LedgerCorrectionService? ledgerCorrectionService,
  }) : _ledgerWriter = ledgerWriter,
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
           );

  final TransactionLedgerWriter _ledgerWriter;
  final LedgerCorrectionService _ledgerCorrectionService;

  @override
  Future<PostedTransactionResult> correctExpense(
    CorrectExpenseCommand cmd,
  ) async {
    return _ledgerWriter.persistMutation(
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
  Future<PostedTransactionResult> correctIncome(
    CorrectIncomeCommand cmd,
  ) async {
    return _ledgerWriter.persistMutation(
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
  Future<PostedTransactionResult> correctTransfer(
    CorrectTransferCommand cmd,
  ) async {
    return _ledgerWriter.persistMutation(
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
          ),
        ),
      ),
    );
  }

  @override
  Future<PostedTransactionResult> correctReimbursementAdvance(
    CorrectReimbursementAdvanceCommand cmd,
  ) async {
    return _ledgerWriter.persistMutation(
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
  Future<PostedTransactionResult> correctRefund(
    CorrectRefundCommand cmd,
  ) async {
    return _ledgerWriter.persistMutation(
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
  Future<PostedTransactionResult> correctReimbursementReceipt(
    CorrectReimbursementReceiptCommand cmd,
  ) async {
    return _ledgerWriter.persistMutation(
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
  Future<PostedTransactionResult> correctReimbursementClose(
    CorrectReimbursementCloseCommand cmd,
  ) async {
    return _ledgerWriter.persistMutation(
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
  Future<PostedTransactionResult> correctBorrowing(
    CorrectBorrowingCommand cmd,
  ) async {
    return _ledgerWriter.persistMutation(
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
  Future<PostedTransactionResult> correctRepayment(
    CorrectRepaymentCommand cmd,
  ) async {
    return _ledgerWriter.persistMutation(
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
  Future<void> deleteTransaction(DeleteTransactionCommand command) async {
    return _ledgerWriter.persistCancellation(
      await _ledgerCorrectionService.cancelTransaction(
        CancelTransactionInstruction(transactionId: command.transactionId),
      ),
    );
  }
}
