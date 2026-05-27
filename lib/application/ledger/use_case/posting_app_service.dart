import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../../../application/shared/transaction_runner.dart';
import '../command/transaction_command.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/valobj/account_usage.dart';
import 'package:smartflow/domain/ledger/valobj/transaction_fact.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/post_receipt.dart';
import '../read_model/transaction_read_models.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/port/posting_repository.dart';
import 'package:smartflow/domain/ledger/port/system_account_resolver.dart';
import 'package:smartflow/domain/ledger/service/account_book.dart';
import 'package:smartflow/domain/ledger/service/account_role_policy.dart';
import 'package:smartflow/domain/ledger/service/entry_reassignment_service.dart';
import 'package:smartflow/domain/ledger/service/receipt_assembler.dart';
import 'package:smartflow/domain/ledger/service/receipt_mutator.dart';
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
    required PostingRepository postingRepository,
    required SystemAccountResolver systemAccountResolver,
    required TransactionRunner transactionRunner,
    ReceiptMutator receiptMutator = const ReceiptMutator(),
    EntryReassignmentService reassignmentService =
        const EntryReassignmentService(),
    ReceiptAssembler receiptAssembler = const ReceiptAssembler(),
    AccountBook accountBook = const AccountBook(),
    AccountRolePolicy? accountRolePolicy,
  }) : _query = transactionQueryService,
       _accountRepository = accountRepository,
       _postingRepository = postingRepository,
       _systemAccounts = systemAccountResolver,
       _transactionRunner = transactionRunner,
       _receiptMutator = receiptMutator,
       _reassignmentService = reassignmentService,
       _assembler = receiptAssembler,
       _accountBook = accountBook,
       _rolePolicy =
           accountRolePolicy ??
           AccountRolePolicy(accountRepository: accountRepository);

  final TransactionQueryService _query;
  final AccountRepository _accountRepository;
  final PostingRepository _postingRepository;
  final SystemAccountResolver _systemAccounts;
  final TransactionRunner _transactionRunner;
  final ReceiptMutator _receiptMutator;
  final EntryReassignmentService _reassignmentService;
  final ReceiptAssembler _assembler;
  final AccountBook _accountBook;
  final AccountRolePolicy _rolePolicy;

  @override
  Future<Result<CreatedTransactionResult>> createExpense(
    CreateExpenseCommand command,
  ) => _runCreate(() => _buildExpense(command));

  @override
  Future<Result<CreatedTransactionResult>> createIncome(
    CreateIncomeCommand command,
  ) => _runCreate(() => _buildIncome(command));

  @override
  Future<Result<CreatedTransactionResult>> createTransfer(
    CreateTransferCommand command,
  ) => _runCreate(() => _buildTransfer(command));

  @override
  Future<Result<CreatedTransactionResult>> createRefund(
    CreateRefundCommand command,
  ) => _runCreate(() => _buildRefund(command));

  @override
  Future<Result<CreatedTransactionResult>> createReimbursementAdvance(
    CreateReimbursementAdvanceCommand command,
  ) => _runCreate(() => _buildReimbursementAdvance(command));

  @override
  Future<Result<CreatedTransactionResult>> createReimbursementReceipt(
    CreateReimbursementReceiptCommand command,
  ) => _runCreate(() => _buildReimbursementReceipt(command));

  @override
  Future<Result<CreatedTransactionResult>> closeReimbursement(
    CloseReimbursementCommand command,
  ) => _runCreate(() => _buildReimbursementClose(command));

  @override
  Future<Result<CreatedTransactionResult>> createRepayment(
    CreateRepaymentCommand command,
  ) => _runCreate(() => _buildRepayment(command));

  @override
  Future<Result<CreatedTransactionResult>> createBorrowing(
    CreateBorrowingCommand command,
  ) => _runCreate(() => _buildBorrowing(command));

  @override
  Future<Result<CreatedTransactionResult>> createOpeningBalance(
    CreateOpeningBalanceCommand command,
  ) => _runCreate(() => _buildOpeningBalance(command));

  @override
  Future<Result<CreatedTransactionResult>> adjustBalance(
    AdjustBalanceCommand command,
  ) => _runCreate(() => _buildBalanceAdjustment(command));

  @override
  Future<Result<CreatedTransactionResult>> correctExpense(
    CorrectExpenseCommand cmd,
  ) {
    return _runCorrection(
      transactionId: cmd.transactionId,
      expectedPurpose: BusinessPurpose.dailyExpense,
      build:
          (original) => _buildExpense(
            CreateExpenseCommand(
              amount: cmd.amount,
              paidFromAccountId: cmd.paidFromAccountId,
              expenseAccountId: cmd.expenseAccountId,
              occurredAt: cmd.occurredAt,
              counterpartyName: cmd.counterpartyName,
              note: cmd.note,
              isExcludedFromStats:
                  cmd.isExcludedFromStats ??
                  original.transaction.isExcludedFromStats,
              isExcludedFromBudget:
                  cmd.isExcludedFromBudget ??
                  original.transaction.isExcludedFromBudget,
            ),
          ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctIncome(
    CorrectIncomeCommand cmd,
  ) {
    return _runCorrection(
      transactionId: cmd.transactionId,
      expectedPurpose: BusinessPurpose.dailyIncome,
      build:
          (original) => _buildIncome(
            CreateIncomeCommand(
              amount: cmd.amount,
              receiveAccountId: cmd.receiveAccountId,
              incomeAccountId: cmd.incomeAccountId,
              occurredAt: cmd.occurredAt,
              counterpartyName: cmd.counterpartyName,
              note: cmd.note,
              isExcludedFromStats:
                  cmd.isExcludedFromStats ??
                  original.transaction.isExcludedFromStats,
              isExcludedFromBudget:
                  cmd.isExcludedFromBudget ??
                  original.transaction.isExcludedFromBudget,
            ),
          ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctTransfer(
    CorrectTransferCommand cmd,
  ) {
    return _runCorrection(
      transactionId: cmd.transactionId,
      expectedPurpose: BusinessPurpose.transfer,
      build:
          (original) => _buildTransfer(
            CreateTransferCommand(
              amount: cmd.amount,
              fromAccountId: cmd.fromAccountId,
              toAccountId: cmd.toAccountId,
              occurredAt: cmd.occurredAt,
              counterpartyName: cmd.counterpartyName,
              note: cmd.note,
              isExcludedFromStats:
                  cmd.isExcludedFromStats ??
                  original.transaction.isExcludedFromStats,
              isExcludedFromBudget:
                  cmd.isExcludedFromBudget ??
                  original.transaction.isExcludedFromBudget,
            ),
          ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctReimbursementAdvance(
    CorrectReimbursementAdvanceCommand cmd,
  ) {
    return _runCorrection(
      transactionId: cmd.transactionId,
      expectedPurpose: BusinessPurpose.reimbursementAdvance,
      build:
          (original) => _buildReimbursementAdvance(
            CreateReimbursementAdvanceCommand(
              amount: cmd.amount,
              receivableAccountId: cmd.receivableAccountId,
              paidFromAccountId: cmd.paidFromAccountId,
              expenseCategoryId: cmd.expenseCategoryId,
              occurredAt: cmd.occurredAt,
              counterpartyName: cmd.counterpartyName,
              note: cmd.note,
              isExcludedFromStats:
                  cmd.isExcludedFromStats ??
                  original.transaction.isExcludedFromStats,
              isExcludedFromBudget:
                  cmd.isExcludedFromBudget ??
                  original.transaction.isExcludedFromBudget,
            ),
          ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctRefund(
    CorrectRefundCommand cmd,
  ) {
    return _runCorrection(
      transactionId: cmd.transactionId,
      expectedPurpose: BusinessPurpose.refund,
      build:
          (original) => _buildRefund(
            CreateRefundCommand(
              amount: cmd.amount,
              parentTransactionId: original.transaction.parentTransactionId!,
              refundToAccountId: cmd.refundToAccountId,
              occurredAt: cmd.occurredAt,
              counterpartyName: cmd.counterpartyName,
              note: cmd.note,
              isExcludedFromStats:
                  cmd.isExcludedFromStats ??
                  original.transaction.isExcludedFromStats,
              isExcludedFromBudget:
                  cmd.isExcludedFromBudget ??
                  original.transaction.isExcludedFromBudget,
            ),
            selfPrimaryAddback: original.transaction.primaryAmount,
          ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctReimbursementReceipt(
    CorrectReimbursementReceiptCommand cmd,
  ) {
    return _runCorrection(
      transactionId: cmd.transactionId,
      expectedPurpose: BusinessPurpose.reimbursementReceipt,
      build:
          (original) => _buildReimbursementReceipt(
            CreateReimbursementReceiptCommand(
              amount: cmd.amount,
              advanceTransactionId:
                  original.transaction.parentTransactionId ??
                  original.transaction.rootTransactionId,
              receivableAccountId: cmd.receivableAccountId,
              receiveAccountId: cmd.receiveAccountId,
              occurredAt: cmd.occurredAt,
              counterpartyName: cmd.counterpartyName,
              note: cmd.note,
              isExcludedFromStats:
                  cmd.isExcludedFromStats ??
                  original.transaction.isExcludedFromStats,
              isExcludedFromBudget:
                  cmd.isExcludedFromBudget ??
                  original.transaction.isExcludedFromBudget,
            ),
            selfPrimaryAddback: original.transaction.primaryAmount,
          ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctReimbursementClose(
    CorrectReimbursementCloseCommand cmd,
  ) {
    return _runCorrection(
      transactionId: cmd.transactionId,
      expectedPurpose: BusinessPurpose.reimbursementClose,
      build:
          (original) => _buildReimbursementClose(
            CloseReimbursementCommand(
              actualReceivedAmount: cmd.actualReceivedAmount,
              advanceTransactionId:
                  original.transaction.parentTransactionId ??
                  original.transaction.rootTransactionId,
              receivableAccountId: cmd.receivableAccountId,
              receiveAccountId: cmd.receiveAccountId,
              occurredAt: cmd.occurredAt,
              counterpartyName: cmd.counterpartyName,
              note: cmd.note,
              isExcludedFromStats:
                  cmd.isExcludedFromStats ??
                  original.transaction.isExcludedFromStats,
              isExcludedFromBudget:
                  cmd.isExcludedFromBudget ??
                  original.transaction.isExcludedFromBudget,
            ),
            outstandingOverride: _detailAmount(
              original,
              TransactionDetailType.reimbursementCloseMain,
            ),
          ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctBorrowing(
    CorrectBorrowingCommand cmd,
  ) {
    return _runCorrection(
      transactionId: cmd.transactionId,
      expectedPurpose: BusinessPurpose.borrowing,
      build:
          (original) => _buildBorrowing(
            CreateBorrowingCommand(
              amount: cmd.amount,
              liabilityAccountId: cmd.liabilityAccountId,
              receiveAccountId: cmd.receiveAccountId,
              occurredAt: cmd.occurredAt,
              counterpartyName: cmd.counterpartyName,
              note: cmd.note,
              ownership: original.transaction.ownership,
              isExcludedFromStats:
                  cmd.isExcludedFromStats ??
                  original.transaction.isExcludedFromStats,
              isExcludedFromBudget:
                  cmd.isExcludedFromBudget ??
                  original.transaction.isExcludedFromBudget,
            ),
          ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctRepayment(
    CorrectRepaymentCommand cmd,
  ) {
    return _runCorrection(
      transactionId: cmd.transactionId,
      expectedPurpose: BusinessPurpose.debtRepayment,
      build:
          (original) => _buildRepayment(
            CreateRepaymentCommand(
              principal: cmd.principal,
              interest: cmd.interest,
              fee: cmd.fee,
              discount: cmd.discount,
              liabilityAccountId: cmd.liabilityAccountId,
              paidFromAccountId: cmd.paidFromAccountId,
              occurredAt: cmd.occurredAt,
              counterpartyName: cmd.counterpartyName,
              note: cmd.note,
              ownership: original.transaction.ownership,
              isExcludedFromStats:
                  cmd.isExcludedFromStats ??
                  original.transaction.isExcludedFromStats,
              isExcludedFromBudget:
                  cmd.isExcludedFromBudget ??
                  original.transaction.isExcludedFromBudget,
            ),
          ),
    );
  }

  @override
  Future<Result<void>> deleteTransaction(DeleteTransactionCommand command) {
    return _transactionRunner.run(() async {
      final target = await _query.findTransactionDetail(command.transactionId);
      if (target == null) {
        return const Result.failure(
          Failure(
            code: 'transaction_not_found',
            message: 'Transaction not found.',
          ),
        );
      }
      if (target.transaction.assertCanBeDeleted() case final failure?) {
        return Result.failure(failure);
      }

      final activeChildIds = <int>{
        for (final child in target.children)
          if (child.businessState == BusinessState.current) child.id,
      };

      final originals = <TransactionFact>[_toFact(target)];
      if (activeChildIds.isNotEmpty) {
        originals.addAll(
          (await _query.findTransactionFacts(activeChildIds)).map(_toFact),
        );
      }

      return _executeCancelMany(originals: originals);
    });
  }

  @override
  Future<Result<void>> updateTransactionMetadata(
    UpdateTransactionMetadataCommand command,
  ) {
    return _transactionRunner.run(() async {
      if (command.note == null &&
          command.isExcludedFromStats == null &&
          command.isExcludedFromBudget == null) {
        return const Result.success(null);
      }
      final transaction = await _query.findTransactionById(
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
        await _postingRepository.updateTransaction(
          transaction.updatedMetadata(
            note: command.note,
            isExcludedFromStats: command.isExcludedFromStats,
            isExcludedFromBudget: command.isExcludedFromBudget,
          ),
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
    });
  }

  @override
  Future<Result<void>> updateTransactionBasics(
    UpdateTransactionBasicsCommand command,
  ) {
    return _transactionRunner.run(() async {
      if (command.occurredAt == null &&
          command.settlementAccountId == null &&
          command.reimbursementAccountId == null) {
        return const Result.success(null);
      }

      final detail = await _query.findTransactionDetail(command.transactionId);
      if (detail == null) {
        return const Result.failure(
          Failure(
            code: 'transaction_not_found',
            message: 'Transaction not found.',
          ),
        );
      }
      if (detail.transaction.assertCanBeBasicsUpdated() case final failure?) {
        return Result.failure(failure);
      }

      final reassignments = <EntryAccountReassignment>[];
      final accountTypes = await _loadAccountTypes(
        detail.entries.map((e) => e.accountId),
      );
      final settlementAccountId = command.settlementAccountId;
      if (settlementAccountId != null) {
        final entry = _reassignmentService.findSettlementEntry(
          businessPurpose: detail.transaction.businessPurpose,
          entries: detail.entries,
          accountTypes: accountTypes,
        );
        if (entry == null) {
          return const Result.failure(
            Failure(
              code: 'settlement_account_not_found',
              message: 'Settlement account cannot be located.',
            ),
          );
        }
        final failure = await _rolePolicy.validate(
          AccountRoleContext([
            AccountRoleRequirement(
              accountId: settlementAccountId,
              expectedTypes: {AccountType.asset, AccountType.liability},
              requiredUsage: AccountUsage.settlement,
              allowReimbursementSubtype: false,
            ),
          ]),
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
        final entry = _reassignmentService.findReimbursementReceivableEntry(
          entries: detail.entries,
          accountTypes: accountTypes,
        );
        if (entry == null) {
          return const Result.failure(
            Failure(
              code: 'reimbursement_account_not_found',
              message: 'Reimbursement account cannot be located.',
            ),
          );
        }
        final failure = await _rolePolicy.validate(
          AccountRoleContext([
            AccountRoleRequirement(
              accountId: reimbursementAccountId,
              expectedTypes: {AccountType.asset},
              requiredSubtype: AccountSubtype.reimbursement,
            ),
          ]),
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
        if (command.occurredAt != null) {
          await _postingRepository.updateTransaction(
            detail.transaction.withOccurredAt(command.occurredAt!),
          );
        }
        for (final reassignment in reassignments) {
          await _postingRepository.reassignEntryAccount(reassignment);
        }
        await _postingRepository.saveAccounts(
          await _updatedAccountsForReassignments(detail, reassignments),
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
    });
  }

  @override
  Future<Result<void>> updateTransactionOwnership(
    UpdateTransactionOwnershipCommand command,
  ) {
    return _transactionRunner.run(() async {
      final transaction = await _query.findTransactionById(
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
        await _postingRepository.updateTransaction(
          transaction.updatedOwnership(command.ownership),
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
    });
  }

  Future<Result<CreatedTransactionResult>> _runCreate(
    Future<Result<PostReceipt>> Function() buildReceipt,
  ) {
    return _transactionRunner.run(() async {
      final receiptResult = await buildReceipt();
      switch (receiptResult) {
        case FailureResult(:final failure):
          return Result.failure(failure);
        case Success(:final value):
          final post = await _executeCreate(value);
          return post.when(
            success:
                (r) => Result.success(
                  CreatedTransactionResult(
                    transactionId: r.transactionId,
                    rootTransactionId: r.rootTransactionId,
                  ),
                ),
            failure: Result.failure,
          );
      }
    });
  }

  Future<Result<CreatedTransactionResult>> _runCorrection({
    required int transactionId,
    required BusinessPurpose expectedPurpose,
    required Future<Result<PostReceipt>> Function(TransactionDetail original)
    build,
  }) {
    return _transactionRunner.run(() async {
      final original = await _query.findTransactionDetail(transactionId);
      if (original == null) {
        return const Result.failure(
          Failure(
            code: 'transaction_not_found',
            message: 'Transaction not found.',
          ),
        );
      }
      if (original.transaction.assertCanBeCorrectedAs(
            expectedPurpose,
            hasActiveChildren: original.children.isNotEmpty,
          )
          case final failure?) {
        return Result.failure(failure);
      }

      final receiptResult = await build(original);
      switch (receiptResult) {
        case FailureResult(:final failure):
          return Result.failure(failure);
        case Success(:final value):
          final post = await _executeReplace(
            original: _toFact(original),
            newReceipt: value,
          );
          return post.when(
            success:
                (r) => Result.success(
                  CreatedTransactionResult(
                    transactionId: r.transactionId,
                    rootTransactionId: r.rootTransactionId,
                  ),
                ),
            failure: Result.failure,
          );
      }
    });
  }

  Money? _detailAmount(TransactionDetail detail, TransactionDetailType type) {
    for (final line in detail.details) {
      if (line.type == type) {
        return line.amount;
      }
    }
    return null;
  }

  TransactionFact _toFact(TransactionDetail detail) {
    return TransactionFact(
      transaction: detail.transaction,
      details: detail.details,
      entries: detail.entries,
    );
  }

  Future<Map<int, AccountType>> _loadAccountTypes(
    Iterable<int> accountIds,
  ) async {
    final ids = accountIds.toSet();
    if (ids.isEmpty) return const {};
    final accounts = await _accountRepository.findByIds(ids);
    return {for (final a in accounts) a.id: a.type};
  }

  Future<List<Account>> _updatedAccountsForReassignments(
    TransactionDetail detail,
    List<EntryAccountReassignment> reassignments,
  ) async {
    if (reassignments.isEmpty) return const [];

    final accountIds = <int>{
      for (final reassignment in reassignments) reassignment.fromAccountId,
      for (final reassignment in reassignments) reassignment.toAccountId,
    };
    final accounts = await _accountRepository.findByIds(accountIds);
    return _reassignmentService.recomputeAccountsForReassignments(
      accounts: {for (final account in accounts) account.id: account},
      scopes: [
        EntryReassignmentScope(
          transactionId: detail.transaction.id,
          rootTransactionId: detail.transaction.rootTransactionId,
          businessState: detail.transaction.businessState,
          entries: detail.entries,
        ),
        for (final child in detail.children)
          EntryReassignmentScope(
            transactionId: child.id,
            rootTransactionId: child.rootTransactionId,
            businessState: child.businessState,
            entries: child.entries,
          ),
      ],
      reassignments: reassignments,
    );
  }

  Future<Result<PostReceiptResult>> _executeCreate(PostReceipt receipt) async {
    try {
      final receiptFailure = receipt.validate();
      if (receiptFailure != null) return Result.failure(receiptFailure);

      final accounts = await _loadAccountsForReceipt(receipt);
      final accountFailure = _validateAccountsLoaded(receipt, accounts);
      if (accountFailure != null) return Result.failure(accountFailure);

      final transaction = Transaction.fromReceipt(receipt);
      final updatedAccounts = _accountBook.applyTransactions(accounts, [
        transaction,
      ]);
      final result = await _postingRepository.saveTransaction(transaction);
      await _postingRepository.saveAccounts(updatedAccounts);
      return Result.success(result);
    } on Object catch (error) {
      return Result.failure(
        Failure(
          code: 'posting_failed',
          message: 'Failed to post transaction.',
          cause: error,
        ),
      );
    }
  }

  Future<Result<PostReceiptResult>> _executeReplace({
    required TransactionFact original,
    required PostReceipt newReceipt,
  }) async {
    try {
      final correctionReceipt = _receiptMutator.inheritFromOriginal(
        newReceipt,
        original,
      );
      final reversalReceipt = _receiptMutator.deriveReversal(original);

      final correctionFailure = correctionReceipt.validate();
      if (correctionFailure != null) return Result.failure(correctionFailure);
      final reversalFailure = reversalReceipt.validate(
        allowNegativeAmounts: true,
      );
      if (reversalFailure != null) return Result.failure(reversalFailure);

      final accountsForCorrection = await _loadAccountsForReceipt(
        correctionReceipt,
      );
      final accountFailure = _validateAccountsLoaded(
        correctionReceipt,
        accountsForCorrection,
      );
      if (accountFailure != null) return Result.failure(accountFailure);

      final reversalTransaction = Transaction.fromReceipt(
        reversalReceipt,
        mutationKind: MutationKind.reversal,
        businessState: BusinessState.compensation,
        mutationReason: MutationReason.correction,
        mutationPreviousTransactionId: original.transaction.id,
      );
      final accountsForWrite = Map<int, Account>.of(accountsForCorrection);
      accountsForWrite.addAll(await _loadAccountsForReceipt(reversalReceipt));
      final afterReversal = _accountBook.applyTransactions(accountsForWrite, [
        reversalTransaction,
      ]);

      await _postingRepository.updateTransactionState(
        transactionId: original.transaction.id,
        businessState: BusinessState.replaced,
      );
      final reversalResult = await _postingRepository.saveTransaction(
        reversalTransaction,
      );

      final correctionTransaction = Transaction.fromReceipt(
        correctionReceipt,
        mutationKind: MutationKind.correction,
        businessState: BusinessState.current,
        mutationPreviousTransactionId: reversalResult.transactionId,
      );
      final afterCorrection = _accountBook.applyTransactions(
        {for (final account in afterReversal) account.id: account},
        [correctionTransaction],
      );
      final result = await _postingRepository.saveTransaction(
        correctionTransaction,
      );
      await _postingRepository.saveAccounts(afterCorrection);
      return Result.success(result);
    } on Object catch (error) {
      return Result.failure(
        Failure(
          code: 'posting_mutation_failed',
          message: 'Failed to mutate transaction.',
          cause: error,
        ),
      );
    }
  }

  Future<Result<void>> _executeCancelMany({
    required List<TransactionFact> originals,
  }) async {
    try {
      final reversalTransactions = <Transaction>[];
      final accountMap = <int, Account>{};
      for (final original in originals) {
        final reversal = _receiptMutator.deriveReversal(original);
        final reversalFailure = reversal.validate(allowNegativeAmounts: true);
        if (reversalFailure != null) return Result.failure(reversalFailure);
        final accounts = await _loadAccountsForReceipt(reversal);
        accountMap.addAll(accounts);
        reversalTransactions.add(
          Transaction.fromReceipt(
            reversal,
            mutationKind: MutationKind.reversal,
            businessState: BusinessState.compensation,
            mutationReason: MutationReason.delete,
            mutationPreviousTransactionId: original.transaction.id,
          ),
        );
      }
      final updatedAccounts = _accountBook.applyTransactions(
        accountMap,
        reversalTransactions,
      );
      for (var i = 0; i < originals.length; i++) {
        await _postingRepository.updateTransactionState(
          transactionId: originals[i].transaction.id,
          businessState: BusinessState.canceled,
        );
        await _postingRepository.saveTransaction(reversalTransactions[i]);
      }
      await _postingRepository.saveAccounts(updatedAccounts);
      return const Result.success(null);
    } on Object catch (error) {
      return Result.failure(
        Failure(
          code: 'posting_mutation_failed',
          message: 'Failed to cancel transaction.',
          cause: error,
        ),
      );
    }
  }

  Future<Map<int, Account>> _loadAccountsForReceipt(PostReceipt receipt) async {
    final ids = receipt.entries.map((e) => e.accountId).toSet();
    final accounts = await _accountRepository.findByIds(ids);
    return {for (final a in accounts) a.id: a};
  }

  Failure? _validateAccountsLoaded(
    PostReceipt receipt,
    Map<int, Account> accounts,
  ) {
    for (final entry in receipt.entries) {
      final account = accounts[entry.accountId];
      if (account == null) {
        return Failure(
          code: 'account_not_found',
          message: 'Account ${entry.accountId} does not exist.',
        );
      }
      if (account.archivedAt != null) {
        return Failure(
          code: 'account_archived',
          message: 'Account ${entry.accountId} is archived.',
        );
      }
    }
    return null;
  }

  // ============================================================
  //  Receipt 构造:Command → 领域事实 → 校验 → 调 assembler → PostReceipt
  // ============================================================

  Future<Result<PostReceipt>> _buildExpense(CreateExpenseCommand cmd) async {
    final roleFailure = await _rolePolicy.validate(
      AccountRoleContext.expense(
        paidFromAccountId: cmd.paidFromAccountId,
        expenseAccountId: cmd.expenseAccountId,
      ),
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return _assembler.assembleExpense(
      amount: cmd.amount,
      paidFromAccountId: cmd.paidFromAccountId,
      expenseAccountId: cmd.expenseAccountId,
      occurredAt: cmd.occurredAt,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  Future<Result<PostReceipt>> _buildIncome(CreateIncomeCommand cmd) async {
    final roleFailure = await _rolePolicy.validate(
      AccountRoleContext.income(
        receiveAccountId: cmd.receiveAccountId,
        incomeAccountId: cmd.incomeAccountId,
      ),
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return _assembler.assembleIncome(
      amount: cmd.amount,
      receiveAccountId: cmd.receiveAccountId,
      incomeAccountId: cmd.incomeAccountId,
      occurredAt: cmd.occurredAt,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  Future<Result<PostReceipt>> _buildTransfer(CreateTransferCommand cmd) async {
    final fee = cmd.feeAmount;
    final feeAccountId = cmd.feeExpenseAccountId;
    final hasFeeAccount =
        fee != null && fee.minorUnits > 0 && feeAccountId != null;
    final roleFailure = await _rolePolicy.validate(
      AccountRoleContext.transfer(
        fromAccountId: cmd.fromAccountId,
        toAccountId: cmd.toAccountId,
        feeExpenseAccountId: hasFeeAccount ? feeAccountId : null,
      ),
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return _assembler.assembleTransfer(
      amount: cmd.amount,
      fromAccountId: cmd.fromAccountId,
      toAccountId: cmd.toAccountId,
      occurredAt: cmd.occurredAt,
      feeAmount: cmd.feeAmount,
      feeExpenseAccountId: cmd.feeExpenseAccountId,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  Future<Result<PostReceipt>> _buildRefund(
    CreateRefundCommand cmd, {
    Money? selfPrimaryAddback,
  }) async {
    final parent = await _query.findTransactionById(cmd.parentTransactionId);
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
      final summary = await _query.getReimbursementSummary(
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
    final refunded = await _query.getRefundedTotal(parent.rootTransactionId);
    final creditAccountId = await _resolveRefundCreditAccount(
      parentId: parent.id,
      parentPurpose: parent.businessPurpose,
    );
    if (creditAccountId == null) {
      return const Result.failure(
        Failure(
          code: 'refund_expense_account_not_found',
          message: 'Original refund target account cannot be located.',
        ),
      );
    }

    final roleFailure = await _rolePolicy.validate(
      AccountRoleContext.refund(refundToAccountId: cmd.refundToAccountId),
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return _assembler.assembleRefund(
      amount: cmd.amount,
      refundToAccountId: cmd.refundToAccountId,
      parent: parent,
      refundedSoFar: refunded,
      creditAccountId: creditAccountId,
      occurredAt: cmd.occurredAt,
      selfPrimaryAddback: selfPrimaryAddback,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  Future<Result<PostReceipt>> _buildReimbursementAdvance(
    CreateReimbursementAdvanceCommand cmd,
  ) async {
    final roleFailure = await _rolePolicy.validate(
      AccountRoleContext.reimbursementAdvance(
        receivableAccountId: cmd.receivableAccountId,
        paidFromAccountId: cmd.paidFromAccountId,
        expenseCategoryId: cmd.expenseCategoryId,
      ),
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return _assembler.assembleReimbursementAdvance(
      amount: cmd.amount,
      receivableAccountId: cmd.receivableAccountId,
      paidFromAccountId: cmd.paidFromAccountId,
      expenseCategoryId: cmd.expenseCategoryId,
      occurredAt: cmd.occurredAt,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  Future<Result<PostReceipt>> _buildReimbursementReceipt(
    CreateReimbursementReceiptCommand cmd, {
    Money? selfPrimaryAddback,
  }) async {
    final advance = await _query.findTransactionById(cmd.advanceTransactionId);
    final advanceFailure = _validateAdvance(advance);
    if (advanceFailure != null) return Result.failure(advanceFailure);

    final summary = await _query.getReimbursementSummary(advance!.id);
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

    final roleFailure = await _rolePolicy.validate(
      AccountRoleContext.reimbursementReceipt(
        receivableAccountId: cmd.receivableAccountId,
        receiveAccountId: cmd.receiveAccountId,
      ),
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return _assembler.assembleReimbursementReceipt(
      amount: cmd.amount,
      advance: advance,
      outstanding: summary.outstanding,
      receivableAccountId: cmd.receivableAccountId,
      receiveAccountId: cmd.receiveAccountId,
      occurredAt: cmd.occurredAt,
      selfPrimaryAddback: selfPrimaryAddback,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  Future<Result<PostReceipt>> _buildReimbursementClose(
    CloseReimbursementCommand cmd, {
    Money? outstandingOverride,
  }) async {
    final advance = await _query.findTransactionById(cmd.advanceTransactionId);
    final advanceFailure = _validateAdvance(advance);
    if (advanceFailure != null) return Result.failure(advanceFailure);

    Money outstanding;
    if (outstandingOverride != null) {
      outstanding = outstandingOverride;
    } else {
      final summary = await _query.getReimbursementSummary(advance!.id);
      if (summary == null || summary.isClosed) {
        return const Result.failure(
          Failure(
            code: 'reimbursement_already_closed',
            message: 'This reimbursement chain is already closed.',
          ),
        );
      }
      outstanding = summary.outstanding;
    }

    final actual = cmd.actualReceivedAmount;
    final hasOverGap = (actual - outstanding).minorUnits > 0;
    final gapIncomeAccountId =
        hasOverGap
            ? await _systemAccounts.resolveReimbursementGapIncome()
            : null;

    final roleFailure = await _rolePolicy.validate(
      AccountRoleContext.reimbursementClose(
        receivableAccountId: cmd.receivableAccountId,
        receiveAccountId: cmd.receiveAccountId,
        receivesCash: actual.minorUnits > 0,
      ),
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return _assembler.assembleReimbursementClose(
      actualReceivedAmount: actual,
      advance: advance!,
      outstanding: outstanding,
      receivableAccountId: cmd.receivableAccountId,
      receiveAccountId: cmd.receiveAccountId,
      occurredAt: cmd.occurredAt,
      gapIncomeAccountId: gapIncomeAccountId,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  Future<Result<PostReceipt>> _buildRepayment(
    CreateRepaymentCommand cmd,
  ) async {
    final hasInterest = cmd.interest != null && cmd.interest!.minorUnits > 0;
    final hasFee = cmd.fee != null && cmd.fee!.minorUnits > 0;
    final hasDiscount = cmd.discount != null && cmd.discount!.minorUnits > 0;

    final interestExpenseAccountId =
        hasInterest ? await _systemAccounts.resolveDebtInterestExpense() : null;
    final feeExpenseAccountId =
        hasFee ? await _systemAccounts.resolveDebtFeeExpense() : null;
    final discountIncomeAccountId =
        hasDiscount ? await _systemAccounts.resolveDiscountIncome() : null;

    final roleFailure = await _rolePolicy.validate(
      AccountRoleContext.repayment(
        liabilityAccountId: cmd.liabilityAccountId,
        paidFromAccountId: cmd.paidFromAccountId,
      ),
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return _assembler.assembleRepayment(
      principal: cmd.principal,
      liabilityAccountId: cmd.liabilityAccountId,
      paidFromAccountId: cmd.paidFromAccountId,
      occurredAt: cmd.occurredAt,
      interest: cmd.interest,
      fee: cmd.fee,
      discount: cmd.discount,
      interestExpenseAccountId: interestExpenseAccountId,
      feeExpenseAccountId: feeExpenseAccountId,
      discountIncomeAccountId: discountIncomeAccountId,
      ownership: cmd.ownership,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  Future<Result<PostReceipt>> _buildBorrowing(
    CreateBorrowingCommand cmd,
  ) async {
    final roleFailure = await _rolePolicy.validate(
      AccountRoleContext.borrowing(
        liabilityAccountId: cmd.liabilityAccountId,
        receiveAccountId: cmd.receiveAccountId,
      ),
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return _assembler.assembleBorrowing(
      amount: cmd.amount,
      liabilityAccountId: cmd.liabilityAccountId,
      receiveAccountId: cmd.receiveAccountId,
      occurredAt: cmd.occurredAt,
      ownership: cmd.ownership,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  Future<Result<PostReceipt>> _buildOpeningBalance(
    CreateOpeningBalanceCommand cmd,
  ) async {
    final account = await _accountRepository.findById(cmd.accountId);
    if (account == null) {
      return const Result.failure(
        Failure(code: 'account_not_found', message: 'Account does not exist.'),
      );
    }
    final equityAccountId = await _systemAccounts.resolveOpeningBalance();
    return _assembler.assembleOpeningBalance(
      account: account,
      signedAmount: cmd.amount,
      equityAccountId: equityAccountId,
      occurredAt: cmd.occurredAt,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  Future<Result<PostReceipt>> _buildBalanceAdjustment(
    AdjustBalanceCommand cmd,
  ) async {
    final account = await _accountRepository.findById(cmd.accountId);
    if (account == null) {
      return const Result.failure(
        Failure(code: 'account_not_found', message: 'Account does not exist.'),
      );
    }
    final deltaResult = account.targetBalanceDeltaTo(cmd.targetBalance);
    switch (deltaResult) {
      case FailureResult(:final failure):
        return Result.failure(failure);
      case Success(:final value):
        final equityAccountId = await _systemAccounts.resolveOpeningBalance();
        return _assembler.assembleBalanceAdjustment(
          account: account,
          signedDelta: value,
          equityAccountId: equityAccountId,
          occurredAt: cmd.occurredAt,
          counterpartyName: cmd.counterpartyName,
          note: cmd.note,
          isExcludedFromStats: cmd.isExcludedFromStats,
          isExcludedFromBudget: cmd.isExcludedFromBudget,
        );
    }
  }

  Future<int?> _resolveRefundCreditAccount({
    required int parentId,
    required BusinessPurpose parentPurpose,
  }) async {
    final detail = await _query.findTransactionDetail(parentId);
    if (detail == null) return null;
    final accountTypes = await _loadAccountTypes(
      detail.entries.map((e) => e.accountId),
    );
    for (final entry in detail.entries) {
      final accountType = accountTypes[entry.accountId];
      final isDailyExpenseTarget =
          parentPurpose == BusinessPurpose.dailyExpense &&
          accountType == AccountType.expense &&
          entry.direction == EntryDirection.debit;
      final isAdvanceTarget =
          parentPurpose == BusinessPurpose.reimbursementAdvance &&
          accountType == AccountType.asset &&
          entry.direction == EntryDirection.debit;
      if (isDailyExpenseTarget || isAdvanceTarget) {
        return entry.accountId;
      }
    }
    return null;
  }

  Failure? _validateAdvance(Transaction? advance) {
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
    return null;
  }
}
