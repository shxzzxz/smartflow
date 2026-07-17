import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/port/transaction_group_repository.dart';
import 'package:smartflow/domain/ledger/port/system_account_resolver.dart';
import 'package:smartflow/domain/ledger/service/account/account_role_policy.dart';
import 'package:smartflow/domain/ledger/service/mutation/transaction_group_rewrite_service.dart';
import 'package:smartflow/domain/ledger/service/posting/account_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_instruction_resolver.dart';
import 'package:smartflow/domain/ledger/valobj/posting_instruction.dart';

import 'transaction_command.dart';
import 'transaction_ledger_writer.dart';

abstract interface class TransactionEditAppService {
  Future<PostedTransactionResult> editExpense(EditExpenseCommand command);

  Future<PostedTransactionResult> editIncome(EditIncomeCommand command);

  Future<PostedTransactionResult> editTransfer(EditTransferCommand command);

  Future<PostedTransactionResult> editReimbursementAdvance(
    EditReimbursementAdvanceCommand command,
  );

  Future<PostedTransactionResult> editRefund(EditRefundCommand command);

  Future<PostedTransactionResult> editReimbursementReceipt(
    EditReimbursementReceiptCommand command,
  );

  Future<PostedTransactionResult> editReimbursementClose(
    EditReimbursementCloseCommand command,
  );

  Future<PostedTransactionResult> editBorrowing(EditBorrowingCommand command);

  Future<PostedTransactionResult> editRepayment(EditRepaymentCommand command);

  Future<void> deleteTransaction(DeleteTransactionCommand command);
}

class TransactionEditAppServiceImpl implements TransactionEditAppService {
  TransactionEditAppServiceImpl({
    required AccountRepository accountRepository,
    required TransactionGroupRepository transactionGroupRepository,
    required SystemAccountResolver systemAccountResolver,
    required TransactionLedgerWriter ledgerWriter,
    required IdGenerator idGenerator,
    AccountRolePolicy? accountRolePolicy,
    PostingEngine? postingEngine,
    PostingInstructionResolver? postingInstructionResolver,
    AccountPostingService accountPostingService =
        const DefaultAccountPostingService(),
    TransactionGroupRewriteService? transactionGroupRewriteService,
  }) : _ledgerWriter = ledgerWriter,
       _transactionGroupRewriteService =
           transactionGroupRewriteService ??
           TransactionGroupRewriteService(
             transactionGroupRepository: transactionGroupRepository,
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
           );

  final TransactionLedgerWriter _ledgerWriter;
  final TransactionGroupRewriteService _transactionGroupRewriteService;

  @override
  Future<PostedTransactionResult> editExpense(EditExpenseCommand cmd) async {
    return _ledgerWriter.planAndPersistRewrite(
      () => _transactionGroupRewriteService.rewriteParentTransaction(
        EditParentTransactionInstruction(
          transactionId: cmd.transactionId,
          occurredAt: cmd.occurredAt,
          counterpartyName: cmd.counterpartyName,
          note: cmd.note,
          isExcludedFromStats: cmd.isExcludedFromStats,
          isExcludedFromBudget: cmd.isExcludedFromBudget,
          editPatch: ExpenseEditPatch(
            amount: cmd.amount,
            paidFromAccountId: cmd.paidFromAccountId,
            expenseAccountId: cmd.expenseAccountId,
          ),
        ),
      ),
    );
  }

  @override
  Future<PostedTransactionResult> editIncome(EditIncomeCommand cmd) async {
    return _ledgerWriter.planAndPersistRewrite(
      () => _transactionGroupRewriteService.rewriteParentTransaction(
        EditParentTransactionInstruction(
          transactionId: cmd.transactionId,
          occurredAt: cmd.occurredAt,
          counterpartyName: cmd.counterpartyName,
          note: cmd.note,
          isExcludedFromStats: cmd.isExcludedFromStats,
          editPatch: IncomeEditPatch(
            amount: cmd.amount,
            receiveAccountId: cmd.receiveAccountId,
            incomeAccountId: cmd.incomeAccountId,
          ),
        ),
      ),
    );
  }

  @override
  Future<PostedTransactionResult> editTransfer(EditTransferCommand cmd) async {
    return _ledgerWriter.planAndPersistRewrite(
      () => _transactionGroupRewriteService.rewriteParentTransaction(
        EditParentTransactionInstruction(
          transactionId: cmd.transactionId,
          occurredAt: cmd.occurredAt,
          counterpartyName: cmd.counterpartyName,
          note: cmd.note,
          editPatch: TransferEditPatch(
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
  Future<PostedTransactionResult> editReimbursementAdvance(
    EditReimbursementAdvanceCommand cmd,
  ) async {
    return _ledgerWriter.planAndPersistRewrite(
      () => _transactionGroupRewriteService.rewriteParentTransaction(
        EditParentTransactionInstruction(
          transactionId: cmd.transactionId,
          occurredAt: cmd.occurredAt,
          counterpartyName: cmd.counterpartyName,
          note: cmd.note,
          isExcludedFromStats: cmd.isExcludedFromStats,
          isExcludedFromBudget: cmd.isExcludedFromBudget,
          editPatch: ReimbursementAdvanceEditPatch(
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
  Future<PostedTransactionResult> editRefund(EditRefundCommand cmd) async {
    return _ledgerWriter.planAndPersistRewrite(
      () => _transactionGroupRewriteService.rewriteRefundTransaction(
        EditRefundTransactionInstruction(
          transactionId: cmd.transactionId,
          occurredAt: cmd.occurredAt,
          counterpartyName: cmd.counterpartyName,
          note: cmd.note,
          editPatch: RefundEditPatch(
            amount: cmd.amount,
            refundToAccountId: cmd.refundToAccountId,
          ),
        ),
      ),
    );
  }

  @override
  Future<PostedTransactionResult> editReimbursementReceipt(
    EditReimbursementReceiptCommand cmd,
  ) async {
    return _ledgerWriter.planAndPersistRewrite(
      () => _transactionGroupRewriteService.rewriteReimbursementReceipt(
        EditReimbursementReceiptTransactionInstruction(
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
  Future<PostedTransactionResult> editReimbursementClose(
    EditReimbursementCloseCommand cmd,
  ) async {
    return _ledgerWriter.planAndPersistRewrite(
      () => _transactionGroupRewriteService.rewriteReimbursementClose(
        EditReimbursementCloseTransactionInstruction(
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
  Future<PostedTransactionResult> editBorrowing(
    EditBorrowingCommand cmd,
  ) async {
    return _ledgerWriter.planAndPersistRewrite(
      () => _transactionGroupRewriteService.rewriteParentTransaction(
        EditParentTransactionInstruction(
          transactionId: cmd.transactionId,
          occurredAt: cmd.occurredAt,
          counterpartyName: cmd.counterpartyName,
          note: cmd.note,
          editPatch: BorrowingEditPatch(
            amount: cmd.amount,
            liabilityAccountId: cmd.liabilityAccountId,
            receiveAccountId: cmd.receiveAccountId,
          ),
        ),
      ),
    );
  }

  @override
  Future<PostedTransactionResult> editRepayment(
    EditRepaymentCommand cmd,
  ) async {
    return _ledgerWriter.planAndPersistRewrite(
      () => _transactionGroupRewriteService.rewriteParentTransaction(
        EditParentTransactionInstruction(
          transactionId: cmd.transactionId,
          occurredAt: cmd.occurredAt,
          counterpartyName: cmd.counterpartyName,
          note: cmd.note,
          editPatch: RepaymentEditPatch(
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
    return _ledgerWriter.planAndPersistDeletion(
      () => _transactionGroupRewriteService.deleteCurrentTransaction(
        command.transactionId,
      ),
    );
  }
}
