import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/result/result.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/port/root_transaction_group_repository.dart';
import 'package:smartflow/domain/ledger/port/system_account_resolver.dart';
import 'package:smartflow/domain/ledger/service/account/account_role_policy.dart';
import 'package:smartflow/domain/ledger/service/posting/account_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/ledger_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_instruction_resolver.dart';
import 'package:smartflow/domain/ledger/service/posting/refund_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/reimbursement_posting_service.dart';
import 'package:smartflow/domain/ledger/valobj/posting_instruction.dart';

import 'transaction_command.dart';
import 'transaction_ledger_writer.dart';

abstract interface class TransactionPostingAppService {
  Future<PostedTransactionResult> createExpense(CreateExpenseCommand command);

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
}

class TransactionPostingAppServiceImpl implements TransactionPostingAppService {
  TransactionPostingAppServiceImpl({
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
    LedgerPostingService? ledgerPostingService,
    RefundPostingService? refundPostingService,
    ReimbursementPostingService? reimbursementPostingService,
  }) : _ledgerWriter = ledgerWriter,
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
           );

  final TransactionLedgerWriter _ledgerWriter;
  final LedgerPostingService _ledgerPostingService;
  final RefundPostingService _refundPostingService;
  final ReimbursementPostingService _reimbursementPostingService;

  @override
  Future<PostedTransactionResult> createExpense(
    CreateExpenseCommand command,
  ) async {
    return _ledgerWriter.persistPostingValue(
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
    return _ledgerWriter.persistPosting(
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
    return _ledgerWriter.persistPosting(
      await _ledgerPostingService.postTransfer(
        TransferInstruction(
          amount: command.amount,
          fromAccountId: command.fromAccountId,
          toAccountId: command.toAccountId,
          occurredAt: command.occurredAt,
          feeAmount: command.feeAmount,
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
    return _ledgerWriter.persistPosting(
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
    return _ledgerWriter.persistPosting(
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
    return _ledgerWriter.persistPosting(
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
    return _ledgerWriter.persistPosting(
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
    return _ledgerWriter.persistPosting(
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
    return _ledgerWriter.persistPosting(
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
    return _ledgerWriter.persistPosting(
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
    return _ledgerWriter.persistPosting(
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
}
