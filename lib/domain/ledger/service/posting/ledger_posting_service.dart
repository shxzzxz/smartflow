import '../../entity/account.dart';
import '../../entity/transaction.dart';
import '../../port/account_repository.dart';
import '../../port/system_account_resolver.dart';
import '../../valobj/ledger_violation_reason.dart';
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

  Future<PostingResult> postExpense(ExpenseInstruction instruction) async {
    final roleViolation = await _accountRolePolicy.validate(
      AccountRoleContext.expense(
        paidFromAccountId: instruction.paidFromAccountId,
        expenseAccountId: instruction.expenseAccountId,
      ),
    );
    if (roleViolation != null) roleViolation.throwException();

    return _applyPosting(_postingEngine.createExpense(instruction));
  }

  Future<PostingResult> postIncome(IncomeInstruction instruction) async {
    final roleViolation = await _accountRolePolicy.validate(
      AccountRoleContext.income(
        receiveAccountId: instruction.receiveAccountId,
        incomeAccountId: instruction.incomeAccountId,
      ),
    );
    if (roleViolation != null) roleViolation.throwException();

    return _applyPosting(_postingEngine.createIncome(instruction));
  }

  Future<PostingResult> postTransfer(TransferInstruction instruction) async {
    final hasFee =
        instruction.feeAmount != null && instruction.feeAmount!.minorUnits > 0;
    final roleViolation = await _accountRolePolicy.validate(
      AccountRoleContext.transfer(
        fromAccountId: instruction.fromAccountId,
        toAccountId: instruction.toAccountId,
      ),
    );
    if (roleViolation != null) roleViolation.throwException();

    return _applyPosting(
      _postingEngine.createTransfer(
        instruction,
        feeExpenseAccountId:
            hasFee ? await _systemAccountResolver.resolveFeeExpense() : null,
      ),
    );
  }

  Future<PostingResult> postRepayment(RepaymentInstruction instruction) async {
    final roleViolation = await _accountRolePolicy.validate(
      AccountRoleContext.repayment(
        liabilityAccountId: instruction.liabilityAccountId,
        paidFromAccountId: instruction.paidFromAccountId,
      ),
    );
    if (roleViolation != null) roleViolation.throwException();

    final hasInterest =
        instruction.interest != null && instruction.interest!.minorUnits > 0;
    final hasFee = instruction.fee != null && instruction.fee!.minorUnits > 0;
    final hasDiscount =
        instruction.discount != null && instruction.discount!.minorUnits > 0;
    return _applyPosting(
      _postingEngine.createRepayment(
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
      ),
    );
  }

  Future<PostingResult> postBorrowing(BorrowingInstruction instruction) async {
    final roleViolation = await _accountRolePolicy.validate(
      AccountRoleContext.borrowing(
        liabilityAccountId: instruction.liabilityAccountId,
        receiveAccountId: instruction.receiveAccountId,
      ),
    );
    if (roleViolation != null) roleViolation.throwException();

    return _applyPosting(_postingEngine.createBorrowing(instruction));
  }

  Future<PostingResult> postOpeningBalance(
    OpeningBalanceInstruction instruction,
  ) async {
    final account = await _accountRepository.findById(instruction.accountId);
    if (account == null) {
      LedgerViolationReason.accountNotFound.throwException();
    }
    return postOpeningBalanceForAccount(
      account: account,
      instruction: instruction,
    );
  }

  Future<PostingResult> postOpeningBalanceForAccount({
    required Account account,
    required OpeningBalanceInstruction instruction,
  }) async {
    if (!account.supportsManualBalance) {
      LedgerViolationReason.openingBalanceNotSupported.throwException(
        message: 'This account type does not support opening balance.',
      );
    }
    final equityAccountId =
        await _systemAccountResolver.resolveOpeningBalance();
    return _applyPosting(
      _postingEngine.createOpeningBalance(
        instruction: instruction,
        account: account,
        equityAccountId: equityAccountId,
      ),
      loadedAccounts: [account],
    );
  }

  Future<PostingResult> postBalanceAdjustment(
    BalanceAdjustmentInstruction instruction,
  ) async {
    final account = await _accountRepository.findById(instruction.accountId);
    if (account == null) {
      LedgerViolationReason.accountNotFound.throwException();
    }
    return postBalanceAdjustmentForAccount(
      account: account,
      instruction: instruction,
    );
  }

  Future<PostingResult> postBalanceAdjustmentForAccount({
    required Account account,
    required BalanceAdjustmentInstruction instruction,
  }) async {
    final adjustmentViolation = account.checkBalanceAdjustmentTarget(
      instruction.targetBalance,
    );
    if (adjustmentViolation != null) adjustmentViolation.throwException();
    final signedDelta = account.balanceDeltaTo(instruction.targetBalance);
    final equityAccountId =
        await _systemAccountResolver.resolveOpeningBalance();
    return _applyPosting(
      _postingEngine.createBalanceAdjustment(
        instruction: instruction,
        account: account,
        signedDelta: signedDelta,
        equityAccountId: equityAccountId,
      ),
      loadedAccounts: [account],
    );
  }

  Future<PostingResult> _applyPosting(
    Transaction transaction, {
    Iterable<Account> loadedAccounts = const [],
  }) async {
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
    final accountViolation = _validateAccountsLoaded(
      transaction.accountIds,
      accountMap,
    );
    if (accountViolation != null) accountViolation.throwException();
    final updated = _accountPostingService.apply(
      transaction: transaction,
      accounts: accountMap,
    );
    return PostingResult(transaction: transaction, accounts: updated);
  }

  LedgerViolationReason? _validateAccountsLoaded(
    Set<String> accountIds,
    Map<String, Account> accounts,
  ) {
    for (final accountId in accountIds) {
      final account = accounts[accountId];
      if (account == null) {
        return LedgerViolationReason.accountNotFound;
      }
      if (account.archivedAt != null) {
        return LedgerViolationReason.accountArchived;
      }
    }
    return null;
  }
}
