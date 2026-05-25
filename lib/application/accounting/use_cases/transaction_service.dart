import '../../../core/errors/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../../../application/shared/transaction_runner.dart';
import '../commands/transaction_commands.dart';
import 'package:smartflow/domain/accounting/entities/account.dart';
import 'package:smartflow/domain/accounting/entities/account_usage.dart';
import 'package:smartflow/domain/accounting/entities/entry.dart';
import 'package:smartflow/domain/accounting/entities/transaction_fact.dart';
import 'package:smartflow/domain/accounting/enums/accounting_enums.dart';
import 'package:smartflow/domain/accounting/ledger/post_receipt.dart';
import 'package:smartflow/domain/accounting/ledger/poster.dart';
import 'receipt_builder.dart';
import '../read_models/transaction_read_models.dart';
import 'package:smartflow/domain/accounting/ports/account_repository.dart';
import 'package:smartflow/domain/accounting/ports/posting_repository.dart';
import '../queries/transaction_query_service.dart';

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
    required TransactionRunner transactionRunner,
  }) : _poster = poster,
       _receipts = receiptBuilder,
       _query = transactionQueryService,
       _accountRepository = accountRepository,
       _postingRepository = postingRepository,
       _transactionRunner = transactionRunner;

  final Poster _poster;
  final ReceiptBuilder _receipts;
  final TransactionQueryService _query;
  final AccountRepository _accountRepository;
  final PostingRepository _postingRepository;
  final TransactionRunner _transactionRunner;

  @override
  Future<Result<CreatedTransactionResult>> createExpense(
    CreateExpenseCommand command,
  ) => _runCreate(() => _receipts.buildExpense(command));

  @override
  Future<Result<CreatedTransactionResult>> createIncome(
    CreateIncomeCommand command,
  ) => _runCreate(() => _receipts.buildIncome(command));

  @override
  Future<Result<CreatedTransactionResult>> createTransfer(
    CreateTransferCommand command,
  ) => _runCreate(() => _receipts.buildTransfer(command));

  @override
  Future<Result<CreatedTransactionResult>> createRefund(
    CreateRefundCommand command,
  ) => _runCreate(() => _receipts.buildRefund(command));

  @override
  Future<Result<CreatedTransactionResult>> createReimbursementAdvance(
    CreateReimbursementAdvanceCommand command,
  ) => _runCreate(() => _receipts.buildReimbursementAdvance(command));

  @override
  Future<Result<CreatedTransactionResult>> createReimbursementReceipt(
    CreateReimbursementReceiptCommand command,
  ) => _runCreate(() => _receipts.buildReimbursementReceipt(command));

  @override
  Future<Result<CreatedTransactionResult>> closeReimbursement(
    CloseReimbursementCommand command,
  ) => _runCreate(() => _receipts.buildReimbursementClose(command));

  @override
  Future<Result<CreatedTransactionResult>> createRepayment(
    CreateRepaymentCommand command,
  ) => _runCreate(() => _receipts.buildRepayment(command));

  @override
  Future<Result<CreatedTransactionResult>> createBorrowing(
    CreateBorrowingCommand command,
  ) => _runCreate(() => _receipts.buildBorrowing(command));

  @override
  Future<Result<CreatedTransactionResult>> createOpeningBalance(
    CreateOpeningBalanceCommand command,
  ) => _runCreate(() => _receipts.buildOpeningBalance(command));

  @override
  Future<Result<CreatedTransactionResult>> adjustBalance(
    AdjustBalanceCommand command,
  ) => _runCreate(() => _receipts.buildBalanceAdjustment(command));

  @override
  Future<Result<CreatedTransactionResult>> correctExpense(
    CorrectExpenseCommand cmd,
  ) {
    return _runCorrection(
      transactionId: cmd.transactionId,
      expectedPurpose: BusinessPurpose.dailyExpense,
      build:
          (original) => _receipts.buildExpense(
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
          (original) => _receipts.buildIncome(
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
          (original) => _receipts.buildTransfer(
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
          (original) => _receipts.buildReimbursementAdvance(
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
          (original) => _receipts.buildRefund(
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
          (original) => _receipts.buildReimbursementReceipt(
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
          (original) => _receipts.buildReimbursementClose(
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
          (original) => _receipts.buildBorrowing(
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
          (original) => _receipts.buildRepayment(
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
      if (target.transaction.businessState != BusinessState.current) {
        return const Result.failure(
          Failure(
            code: 'transaction_not_current',
            message: 'Only current transactions can be deleted.',
          ),
        );
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

      return _poster.cancelMany(originals: originals);
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
          updatedAccounts: await _updatedAccountsForReassignments(
            detail,
            reassignments,
          ),
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
          final post = await _poster.create(value);
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
      if (original.children.isNotEmpty) {
        return const Result.failure(
          Failure(
            code: 'transaction_has_children',
            message:
                'Transactions with child records cannot be corrected; '
                'use updateTransactionMetadata to change note / exclusion flags.',
          ),
        );
      }

      final receiptResult = await build(original);
      switch (receiptResult) {
        case FailureResult(:final failure):
          return Result.failure(failure);
        case Success(:final value):
          final post = await _poster.replace(
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

  Future<Failure?> _validateDirectAccount(
    int accountId, {
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
    final accounts = await _accountRepository.findAccountsByIds(ids);
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
    final accounts = await _accountRepository.findAccountsByIds(accountIds);
    final updated = {for (final account in accounts) account.id: account};

    for (final reassignment in reassignments) {
      final oldAccount = updated[reassignment.fromAccountId];
      final newAccount = updated[reassignment.toAccountId];
      if (oldAccount == null || newAccount == null) {
        throw StateError(
          'Cannot reassign entry account because account is missing.',
        );
      }
      if (reassignment.fromAccountId == reassignment.toAccountId) {
        continue;
      }

      final affectedEntries = _entriesForReassignment(detail, reassignment);
      for (final entry in affectedEntries) {
        final oldImpact = ReceiptEntry(
          accountId: reassignment.fromAccountId,
          direction: entry.direction,
          amount: entry.amount,
        );
        final newImpact = ReceiptEntry(
          accountId: reassignment.toAccountId,
          direction: entry.direction,
          amount: entry.amount,
        );
        updated[oldAccount.id] = updated[oldAccount.id]!.removeEntryImpact(
          oldImpact,
        );
        updated[newAccount.id] = updated[newAccount.id]!.applyEntryImpact(
          newImpact,
        );
      }
    }

    return updated.values.toList();
  }

  List<Entry> _entriesForReassignment(
    TransactionDetail detail,
    EntryAccountReassignment reassignment,
  ) {
    final transactionId = reassignment.transactionId;
    if (transactionId != null) {
      return [
        for (final entry in detail.entries)
          if (entry.transactionId == transactionId &&
              entry.accountId == reassignment.fromAccountId)
            entry,
      ];
    }

    final rootTransactionId = reassignment.rootTransactionId!;
    return [
      if (detail.transaction.rootTransactionId == rootTransactionId &&
          detail.transaction.businessState == BusinessState.current)
        for (final entry in detail.entries)
          if (entry.accountId == reassignment.fromAccountId) entry,
      for (final child in detail.children)
        if (child.rootTransactionId == rootTransactionId &&
            child.businessState == BusinessState.current)
          for (final entry in child.entries)
            if (entry.accountId == reassignment.fromAccountId) entry,
    ];
  }
}
