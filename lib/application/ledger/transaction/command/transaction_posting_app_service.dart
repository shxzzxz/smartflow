import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/port/transaction_group_repository.dart';
import 'package:smartflow/domain/ledger/port/system_account_resolver.dart';
import 'package:smartflow/domain/ledger/service/account/account_role_policy.dart';
import 'package:smartflow/domain/ledger/service/posting/account_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/ledger_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/domain/ledger/service/posting/refund_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/advance_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_application_service.dart';
import 'package:smartflow/domain/ledger/valobj/posting_instruction.dart';

import 'transaction_command.dart';
import 'transaction_ledger_writer.dart';

abstract interface class TransactionPostingAppService {
  Future<PostedTransactionResult> createExpense(CreateExpenseCommand command);

  Future<PostedTransactionResult> createIncome(CreateIncomeCommand command);

  Future<PostedTransactionResult> createTransfer(CreateTransferCommand command);

  Future<PostedTransactionResult> createRefund(CreateRefundCommand command);

  Future<PostedTransactionResult> createAdvance(CreateAdvanceCommand command);

  Future<PostedTransactionResult> createAdvanceCollection(
    CreateAdvanceCollectionCommand command,
  );

  Future<PostedTransactionResult> settleAdvance(
    CreateAdvanceSettlementCommand command,
  );

  Future<PostedTransactionResult> createRepayment(
    CreateRepaymentCommand command,
  );

  Future<PostedTransactionResult> createBorrowing(
    CreateBorrowingCommand command,
  );

  Future<PostedTransactionResult> createOpeningBalance(
    CreateOpeningBalanceCommand command,
  );

  Future<PostedTransactionResult> adjustBalance(AdjustBalanceCommand command);
}

abstract interface class ReceivableTransactionPostingAppService {
  Future<PostedTransactionResult> createLending(CreateLendingCommand command);
  Future<PostedTransactionResult> createReceivableCollection(
    CreateReceivableCollectionCommand command,
  );
  Future<PostedTransactionResult> createBadDebt(CreateBadDebtCommand command);
  Future<PostedTransactionResult> createDebtRelief(
    CreateDebtReliefCommand command,
  );
}

class TransactionPostingAppServiceImpl
    implements
        TransactionPostingAppService,
        ReceivableTransactionPostingAppService {
  TransactionPostingAppServiceImpl({
    required AccountRepository accountRepository,
    required TransactionGroupRepository transactionGroupRepository,
    required SystemAccountResolver systemAccountResolver,
    required TransactionLedgerWriter ledgerWriter,
    required IdGenerator idGenerator,
    AccountRolePolicy? accountRolePolicy,
    PostingEngine? postingEngine,
    AccountPostingService accountPostingService =
        const DefaultAccountPostingService(),
    LedgerPostingService? ledgerPostingService,
    RefundPostingService? refundPostingService,
    AdvancePostingService? advancePostingService,
    PostingApplicationService? postingApplicationService,
  }) : this._withPostingApplication(
         accountRepository: accountRepository,
         transactionGroupRepository: transactionGroupRepository,
         systemAccountResolver: systemAccountResolver,
         ledgerWriter: ledgerWriter,
         idGenerator: idGenerator,
         accountRolePolicy: accountRolePolicy,
         postingEngine: postingEngine,
         accountPostingService: accountPostingService,
         ledgerPostingService: ledgerPostingService,
         refundPostingService: refundPostingService,
         advancePostingService: advancePostingService,
         postingApplicationService:
             postingApplicationService ??
             PostingApplicationService(
               accountRepository: accountRepository,
               accountPostingService: accountPostingService,
             ),
       );

  TransactionPostingAppServiceImpl._withPostingApplication({
    required AccountRepository accountRepository,
    required TransactionGroupRepository transactionGroupRepository,
    required SystemAccountResolver systemAccountResolver,
    required TransactionLedgerWriter ledgerWriter,
    required IdGenerator idGenerator,
    AccountRolePolicy? accountRolePolicy,
    PostingEngine? postingEngine,
    required AccountPostingService accountPostingService,
    LedgerPostingService? ledgerPostingService,
    RefundPostingService? refundPostingService,
    AdvancePostingService? advancePostingService,
    required PostingApplicationService postingApplicationService,
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
             postingApplicationService: postingApplicationService,
           ),
       _refundPostingService =
           refundPostingService ??
           RefundPostingService(
             transactionGroupRepository: transactionGroupRepository,
             accountRepository: accountRepository,
             postingEngine:
                 postingEngine ?? PostingEngine(idGenerator: idGenerator),
             accountPostingService: accountPostingService,
             accountRolePolicy:
                 accountRolePolicy ??
                 AccountRolePolicy(accountRepository: accountRepository),
             postingApplicationService: postingApplicationService,
           ),
       _advancePostingService =
           advancePostingService ??
           AdvancePostingService(
             transactionGroupRepository: transactionGroupRepository,
             accountRepository: accountRepository,
             systemAccountResolver: systemAccountResolver,
             postingEngine:
                 postingEngine ?? PostingEngine(idGenerator: idGenerator),
             accountPostingService: accountPostingService,
             accountRolePolicy:
                 accountRolePolicy ??
                 AccountRolePolicy(accountRepository: accountRepository),
             postingApplicationService: postingApplicationService,
           );

  final TransactionLedgerWriter _ledgerWriter;
  final LedgerPostingService _ledgerPostingService;
  final RefundPostingService _refundPostingService;
  final AdvancePostingService _advancePostingService;

  @override
  Future<PostedTransactionResult> createExpense(
    CreateExpenseCommand command,
  ) async {
    return _ledgerWriter.persistPosting(
      await _ledgerPostingService.postExpense(
        ExpenseInstruction(
          amount: command.amount,
          categoryAllocations: command.categoryAllocations,
          settlementAllocations: command.settlementAllocations,
          occurredAt: command.occurredAt,
          postedAt: command.postedAt,
          counterpartyId: command.counterpartyId,
          note: command.note,
          isExcludedFromStats: command.isExcludedFromStats,
          isExcludedFromBudget: command.isExcludedFromBudget,
          sourceKind: command.sourceKind,
          ownership: command.ownership,
        ),
      ),
      tagIds: command.tagIds,
    );
  }

  @override
  Future<PostedTransactionResult> createIncome(
    CreateIncomeCommand command,
  ) async {
    return _ledgerWriter.persistPosting(
      await _ledgerPostingService.postIncome(
        IncomeInstruction(
          amount: command.amount,
          categoryAllocations: command.categoryAllocations,
          settlementAllocations: command.settlementAllocations,
          occurredAt: command.occurredAt,
          postedAt: command.postedAt,
          counterpartyId: command.counterpartyId,
          note: command.note,
          isExcludedFromStats: command.isExcludedFromStats,
          isExcludedFromBudget: command.isExcludedFromBudget,
          sourceKind: command.sourceKind,
          ownership: command.ownership,
        ),
      ),
      tagIds: command.tagIds,
    );
  }

  @override
  Future<PostedTransactionResult> createTransfer(
    CreateTransferCommand command,
  ) async {
    return _ledgerWriter.persistPosting(
      await _ledgerPostingService.postTransfer(
        TransferInstruction(
          amount: command.amount,
          fromAccountId: command.fromAccountId,
          toAccountId: command.toAccountId,
          occurredAt: command.occurredAt,
          postedAt: command.postedAt,
          feeAmount: command.feeAmount,
          counterpartyId: command.counterpartyId,
          note: command.note,
          ownership: command.ownership,
          isExcludedFromStats: command.isExcludedFromStats,
          isExcludedFromBudget: command.isExcludedFromBudget,
          sourceKind: command.sourceKind,
        ),
      ),
      tagIds: command.tagIds,
    );
  }

  @override
  Future<PostedTransactionResult> createRefund(
    CreateRefundCommand command,
  ) async {
    return _ledgerWriter.persistPosting(
      await _refundPostingService.postRefund(
        RefundInstruction(
          parentTransactionId: command.parentTransactionId,
          amount: command.amount,
          categoryAllocations: command.categoryAllocations,
          selfBorneAllocations: command.selfBorneAllocations,
          settlementAllocations: command.settlementAllocations,
          occurredAt: command.occurredAt,
          postedAt: command.postedAt,
          counterpartyId: command.counterpartyId,
          note: command.note,
        ),
      ),
    );
  }

  @override
  Future<PostedTransactionResult> createAdvance(
    CreateAdvanceCommand command,
  ) async {
    return _ledgerWriter.persistPosting(
      await _advancePostingService.postAdvance(
        AdvanceInstruction(
          amount: command.amount,
          advanceAmount: command.advanceAmount,
          receivableAccountId: command.receivableAccountId,
          categoryAllocations: command.categoryAllocations,
          selfBorneAllocations: command.selfBorneAllocations,
          settlementAllocations: command.settlementAllocations,
          occurredAt: command.occurredAt,
          ownership: command.ownership,
          postedAt: command.postedAt,
          counterpartyId: command.counterpartyId,
          note: command.note,
          isExcludedFromStats: command.isExcludedFromStats,
          isExcludedFromBudget: command.isExcludedFromBudget,
          sourceKind: command.sourceKind,
        ),
      ),
      tagIds: command.tagIds,
    );
  }

  @override
  Future<PostedTransactionResult> createAdvanceCollection(
    CreateAdvanceCollectionCommand command,
  ) async {
    final instruction = AdvanceCollectionInstruction(
      advanceTransactionId: command.advanceTransactionId,
      amount: command.amount,
      receivableAccountId: command.receivableAccountId,
      settlementAllocations: command.settlementAllocations,
      occurredAt: command.occurredAt,
      postedAt: command.postedAt,
      counterpartyId: command.counterpartyId,
      note: command.note,
    );
    return _ledgerWriter.persistPosting(
      await _advancePostingService.postCollection(instruction),
    );
  }

  @override
  Future<PostedTransactionResult> settleAdvance(
    CreateAdvanceSettlementCommand command,
  ) async {
    final instruction = AdvanceSettlementInstruction(
      advanceTransactionId: command.advanceTransactionId,
      actualReceivedAmount: command.actualReceivedAmount,
      receivableAccountId: command.receivableAccountId,
      settlementAllocations: command.settlementAllocations,
      gapExpenseAllocations: command.gapExpenseAllocations,
      shortfallKind: command.shortfallKind,
      occurredAt: command.occurredAt,
      postedAt: command.postedAt,
      counterpartyId: command.counterpartyId,
      note: command.note,
    );
    return _ledgerWriter.persistPosting(
      await _advancePostingService.settle(instruction),
    );
  }

  @override
  Future<PostedTransactionResult> createRepayment(
    CreateRepaymentCommand command,
  ) async {
    return _ledgerWriter.persistPosting(
      await _ledgerPostingService.postRepayment(
        RepaymentInstruction(
          principal: command.principal,
          liabilityAccountId: command.liabilityAccountId,
          paidFromAccountId: command.paidFromAccountId,
          occurredAt: command.occurredAt,
          postedAt: command.postedAt,
          interest: command.interest,
          fee: command.fee,
          discount: command.discount,
          counterpartyId: command.counterpartyId,
          note: command.note,
          ownership: command.ownership,
          sourceKind: command.sourceKind,
        ),
      ),
      tagIds: command.tagIds,
    );
  }

  @override
  Future<PostedTransactionResult> createBorrowing(
    CreateBorrowingCommand command,
  ) async {
    return _ledgerWriter.persistPosting(
      await _ledgerPostingService.postBorrowing(
        BorrowingInstruction(
          amount: command.amount,
          liabilityAccountId: command.liabilityAccountId,
          receiveAccountId: command.receiveAccountId,
          occurredAt: command.occurredAt,
          postedAt: command.postedAt,
          counterpartyId: command.counterpartyId,
          note: command.note,
          ownership: command.ownership,
          sourceKind: command.sourceKind,
        ),
      ),
      tagIds: command.tagIds,
    );
  }

  @override
  Future<PostedTransactionResult> createLending(
    CreateLendingCommand command,
  ) async => _ledgerWriter.persistPosting(
    await _ledgerPostingService.postLending(
      LendingInstruction(
        amount: command.amount,
        receivableAccountId: command.receivableAccountId,
        paidFromAccountId: command.paidFromAccountId,
        occurredAt: command.occurredAt,
        postedAt: command.postedAt,
        counterpartyId: command.counterpartyId,
        note: command.note,
      ),
    ),
    tagIds: command.tagIds,
  );

  @override
  Future<PostedTransactionResult> createReceivableCollection(
    CreateReceivableCollectionCommand command,
  ) async => _ledgerWriter.persistPosting(
    await _ledgerPostingService.postReceivableCollection(
      ReceivableCollectionInstruction(
        principal: command.principal,
        interest: command.interest,
        receivableAccountId: command.receivableAccountId,
        receiveAccountId: command.receiveAccountId,
        occurredAt: command.occurredAt,
        postedAt: command.postedAt,
        counterpartyId: command.counterpartyId,
        note: command.note,
      ),
    ),
    tagIds: command.tagIds,
  );

  @override
  Future<PostedTransactionResult> createBadDebt(
    CreateBadDebtCommand command,
  ) async => _ledgerWriter.persistPosting(
    await _ledgerPostingService.postBadDebt(
      BadDebtInstruction(
        amount: command.amount,
        receivableAccountId: command.receivableAccountId,
        occurredAt: command.occurredAt,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
        postedAt: command.postedAt,
        counterpartyId: command.counterpartyId,
        note: command.note,
      ),
    ),
    tagIds: command.tagIds,
  );

  @override
  Future<PostedTransactionResult> createDebtRelief(
    CreateDebtReliefCommand command,
  ) async => _ledgerWriter.persistPosting(
    await _ledgerPostingService.postDebtRelief(
      DebtReliefInstruction(
        amount: command.amount,
        liabilityAccountId: command.liabilityAccountId,
        occurredAt: command.occurredAt,
        isExcludedFromStats: command.isExcludedFromStats,
        postedAt: command.postedAt,
        counterpartyId: command.counterpartyId,
        note: command.note,
      ),
    ),
    tagIds: command.tagIds,
  );

  @override
  Future<PostedTransactionResult> createOpeningBalance(
    CreateOpeningBalanceCommand command,
  ) async {
    return _ledgerWriter.persistPosting(
      await _ledgerPostingService.postOpeningBalance(
        OpeningBalanceInstruction(
          accountId: command.accountId,
          amount: command.amount,
          occurredAt: command.occurredAt,
          postedAt: command.postedAt,
          counterpartyId: command.counterpartyId,
          note: command.note,
          sourceKind: command.sourceKind,
        ),
      ),
    );
  }

  @override
  Future<PostedTransactionResult> adjustBalance(
    AdjustBalanceCommand command,
  ) async {
    return _ledgerWriter.persistPosting(
      await _ledgerPostingService.postBalanceAdjustment(
        BalanceAdjustmentInstruction(
          accountId: command.accountId,
          targetBalance: command.targetBalance,
          occurredAt: command.occurredAt,
          counterpartyId: command.counterpartyId,
          note: command.note,
        ),
      ),
    );
  }
}
