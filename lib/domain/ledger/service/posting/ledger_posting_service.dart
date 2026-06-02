import 'package:smartflow/core/error/failure.dart';
import 'package:smartflow/core/result/result.dart';
import '../../entity/account.dart';
import '../../entity/transaction.dart';
import '../../port/account_repository.dart';
import '../../port/system_account_resolver.dart';
import '../../valobj/posting_instruction.dart';
import '../../valobj/posting_result.dart';
import '../account/account_role_policy.dart';
import 'account_posting_service.dart';
import 'posting_engine.dart';

class LedgerPostingService {
  const LedgerPostingService({
    required AccountRepository accountRepository,
    required SystemAccountResolver systemAccountResolver,
    required PostingEngine postingEngine,
    required AccountPostingService accountPostingService,
    required AccountRolePolicy accountRolePolicy,
  }) : _accountRepository = accountRepository,
       _systemAccountResolver = systemAccountResolver,
       _postingEngine = postingEngine,
       _accountPostingService = accountPostingService,
       _accountRolePolicy = accountRolePolicy;

  final AccountRepository _accountRepository;
  final SystemAccountResolver _systemAccountResolver;
  final PostingEngine _postingEngine;
  final AccountPostingService _accountPostingService;
  final AccountRolePolicy _accountRolePolicy;

  Future<Result<PostingResult>> postExpense(
    ExpenseInstruction instruction,
  ) async {
    final roleFailure = await _accountRolePolicy.validate(
      AccountRoleContext.expense(
        paidFromAccountId: instruction.paidFromAccountId,
        expenseAccountId: instruction.expenseAccountId,
      ),
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    final transactionResult = _postingEngine.createExpense(instruction);
    if (transactionResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return _applyPosting(transactionResult.value);
  }

  Future<Result<PostingResult>> postIncome(
    IncomeInstruction instruction,
  ) async {
    final roleFailure = await _accountRolePolicy.validate(
      AccountRoleContext.income(
        receiveAccountId: instruction.receiveAccountId,
        incomeAccountId: instruction.incomeAccountId,
      ),
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    final transactionResult = _postingEngine.createIncome(instruction);
    if (transactionResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return _applyPosting(transactionResult.value);
  }

  Future<Result<PostingResult>> postTransfer(
    TransferInstruction instruction,
  ) async {
    final hasFee =
        instruction.feeAmount != null && instruction.feeAmount!.minorUnits > 0;
    final roleFailure = await _accountRolePolicy.validate(
      AccountRoleContext.transfer(
        fromAccountId: instruction.fromAccountId,
        toAccountId: instruction.toAccountId,
      ),
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    final transactionResult = _postingEngine.createTransfer(
      instruction,
      feeExpenseAccountId:
          hasFee ? await _systemAccountResolver.resolveFeeExpense() : null,
    );
    if (transactionResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return _applyPosting(transactionResult.value);
  }

  Future<Result<PostingResult>> postRepayment(
    RepaymentInstruction instruction,
  ) async {
    final roleFailure = await _accountRolePolicy.validate(
      AccountRoleContext.repayment(
        liabilityAccountId: instruction.liabilityAccountId,
        paidFromAccountId: instruction.paidFromAccountId,
      ),
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    final hasInterest =
        instruction.interest != null && instruction.interest!.minorUnits > 0;
    final hasFee = instruction.fee != null && instruction.fee!.minorUnits > 0;
    final hasDiscount =
        instruction.discount != null && instruction.discount!.minorUnits > 0;
    final transactionResult = _postingEngine.createRepayment(
      instruction,
      interestExpenseAccountId:
          hasInterest
              ? await _systemAccountResolver.resolveInterestExpense()
              : null,
      feeExpenseAccountId:
          hasFee ? await _systemAccountResolver.resolveFeeExpense() : null,
      discountIncomeAccountId:
          hasDiscount
              ? await _systemAccountResolver.resolveDiscountIncome()
              : null,
    );
    if (transactionResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return _applyPosting(transactionResult.value);
  }

  Future<Result<PostingResult>> postBorrowing(
    BorrowingInstruction instruction,
  ) async {
    final roleFailure = await _accountRolePolicy.validate(
      AccountRoleContext.borrowing(
        liabilityAccountId: instruction.liabilityAccountId,
        receiveAccountId: instruction.receiveAccountId,
      ),
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    final transactionResult = _postingEngine.createBorrowing(instruction);
    if (transactionResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return _applyPosting(transactionResult.value);
  }

  Future<Result<PostingResult>> postOpeningBalance(
    OpeningBalanceInstruction instruction,
  ) async {
    final account = await _accountRepository.findById(instruction.accountId);
    if (account == null) {
      return const Result.failure(
        Failure(code: 'account_not_found', message: 'Account does not exist.'),
      );
    }
    return postOpeningBalanceForAccount(
      account: account,
      instruction: instruction,
    );
  }

  Future<Result<PostingResult>> postOpeningBalanceForAccount({
    required Account account,
    required OpeningBalanceInstruction instruction,
  }) async {
    if (!account.supportsManualBalance) {
      return const Result.failure(
        Failure(
          code: 'opening_balance_not_supported',
          message: 'This account type does not support opening balance.',
        ),
      );
    }
    final equityAccountId =
        await _systemAccountResolver.resolveOpeningBalance();
    final transactionResult = _postingEngine.createOpeningBalance(
      instruction: instruction,
      account: account,
      equityAccountId: equityAccountId,
    );
    if (transactionResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return _applyPosting(transactionResult.value, loadedAccounts: [account]);
  }

  Future<Result<PostingResult>> postBalanceAdjustment(
    BalanceAdjustmentInstruction instruction,
  ) async {
    final account = await _accountRepository.findById(instruction.accountId);
    if (account == null) {
      return const Result.failure(
        Failure(code: 'account_not_found', message: 'Account does not exist.'),
      );
    }
    return postBalanceAdjustmentForAccount(
      account: account,
      instruction: instruction,
    );
  }

  Future<Result<PostingResult>> postBalanceAdjustmentForAccount({
    required Account account,
    required BalanceAdjustmentInstruction instruction,
  }) async {
    final deltaResult = account.targetBalanceDeltaTo(instruction.targetBalance);
    if (deltaResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final equityAccountId =
        await _systemAccountResolver.resolveOpeningBalance();
    final transactionResult = _postingEngine.createBalanceAdjustment(
      instruction: instruction,
      account: account,
      signedDelta: deltaResult.value,
      equityAccountId: equityAccountId,
    );
    if (transactionResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return _applyPosting(transactionResult.value, loadedAccounts: [account]);
  }

  Future<Result<PostingResult>> _applyPosting(
    Transaction transaction, {
    Iterable<Account> loadedAccounts = const [],
  }) async {
    try {
      final accountMap = {
        for (final account in loadedAccounts) account.id: account,
      };
      final missingIds = transaction.accountIds.difference(
        accountMap.keys.toSet(),
      );
      if (missingIds.isNotEmpty) {
        final accounts = await _accountRepository.findByIds(missingIds);
        accountMap.addEntries(
          accounts.map((account) => MapEntry(account.id, account)),
        );
      }
      final missingFailure = _validateAccountsLoaded(
        transaction.accountIds,
        accountMap,
      );
      if (missingFailure != null) return Result.failure(missingFailure);
      final updated = _accountPostingService.apply(
        transaction: transaction,
        accounts: accountMap,
      );
      return Result.success(
        PostingResult(transaction: transaction, accounts: updated),
      );
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

  Failure? _validateAccountsLoaded(
    Set<String> accountIds,
    Map<String, Account> accounts,
  ) {
    for (final accountId in accountIds) {
      final account = accounts[accountId];
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
    }
    return null;
  }
}
