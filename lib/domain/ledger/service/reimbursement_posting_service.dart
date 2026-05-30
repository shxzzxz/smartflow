import '../../../core/error/failure.dart';
import '../../../core/result/result.dart';
import '../entity/account.dart';
import '../entity/transaction.dart';
import '../port/account_repository.dart';
import '../port/root_transaction_group_repository.dart';
import '../port/system_account_resolver.dart';
import '../valobj/ledger_enum.dart';
import '../valobj/posting_instruction.dart';
import '../valobj/posting_result.dart';
import 'account_posting_service.dart';
import 'account_role_policy.dart';
import 'posting_engine.dart';

class ReimbursementPostingService {
  const ReimbursementPostingService({
    required RootTransactionGroupRepository rootGroupRepository,
    required AccountRepository accountRepository,
    required SystemAccountResolver systemAccountResolver,
    required PostingEngine postingEngine,
    required AccountPostingService accountPostingService,
    required AccountRolePolicy accountRolePolicy,
  }) : _rootGroupRepository = rootGroupRepository,
       _accountRepository = accountRepository,
       _systemAccountResolver = systemAccountResolver,
       _postingEngine = postingEngine,
       _accountPostingService = accountPostingService,
       _accountRolePolicy = accountRolePolicy;

  final RootTransactionGroupRepository _rootGroupRepository;
  final AccountRepository _accountRepository;
  final SystemAccountResolver _systemAccountResolver;
  final PostingEngine _postingEngine;
  final AccountPostingService _accountPostingService;
  final AccountRolePolicy _accountRolePolicy;

  Future<Result<PostingResult>> postAdvance(
    ReimbursementAdvanceInstruction instruction,
  ) async {
    final roleFailure = await _accountRolePolicy.validate(
      AccountRoleContext.reimbursementAdvance(
        receivableAccountId: instruction.receivableAccountId,
        paidFromAccountId: instruction.paidFromAccountId,
        expenseCategoryId: instruction.expenseAccountId,
      ),
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    final transactionResult = _postingEngine.createReimbursementAdvance(
      instruction,
    );
    if (transactionResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return _applyPosting(transactionResult.value);
  }

  Future<Result<PostingResult>> postReceipt(
    ReimbursementReceiptInstruction instruction,
  ) async {
    final group = await _rootGroupRepository.findByTransactionId(
      instruction.advanceTransactionId,
    );
    if (group == null ||
        group.parentTransaction.id != instruction.advanceTransactionId ||
        group.parentTransaction.businessPurpose !=
            BusinessPurpose.reimbursementAdvance) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_advance_not_found',
          message: 'Reimbursement advance not found.',
        ),
      );
    }
    final advance = group.parentTransaction;
    if (advance.businessState != BusinessState.current) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_advance_not_current',
          message: 'Reimbursement advance is not current.',
        ),
      );
    }
    if (group.reimbursementClosed) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_already_closed',
          message: 'This reimbursement chain is already closed.',
        ),
      );
    }
    final outstanding =
        advance.primaryAmount - group.reimbursementReceivedTotal();
    if (instruction.amount.minorUnits > outstanding.minorUnits) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_receipt_exceeds_outstanding',
          message: 'Receipt exceeds outstanding receivable.',
        ),
      );
    }

    final roleFailure = await _accountRolePolicy.validate(
      AccountRoleContext.reimbursementReceipt(
        receivableAccountId: instruction.receivableAccountId,
        receiveAccountId: instruction.receiveAccountId,
      ),
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    final transactionResult = _postingEngine.createReimbursementReceipt(
      instruction: instruction,
      advance: advance,
    );
    if (transactionResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return _applyPosting(transactionResult.value);
  }

  Future<Result<PostingResult>> close(
    ReimbursementCloseInstruction instruction,
  ) async {
    final group = await _rootGroupRepository.findByTransactionId(
      instruction.advanceTransactionId,
    );
    if (group == null ||
        group.parentTransaction.id != instruction.advanceTransactionId ||
        group.parentTransaction.businessPurpose !=
            BusinessPurpose.reimbursementAdvance) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_advance_not_found',
          message: 'Reimbursement advance not found.',
        ),
      );
    }
    final advance = group.parentTransaction;
    if (advance.businessState != BusinessState.current) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_advance_not_current',
          message: 'Reimbursement advance is not current.',
        ),
      );
    }
    if (group.reimbursementClosed) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_already_closed',
          message: 'This reimbursement chain is already closed.',
        ),
      );
    }
    final outstanding =
        advance.primaryAmount - group.reimbursementReceivedTotal();
    final actual = instruction.actualReceivedAmount;
    final gapIncomeAccountId =
        actual.minorUnits > outstanding.minorUnits
            ? await _systemAccountResolver.resolveReimbursementGapIncome()
            : null;

    final roleFailure = await _accountRolePolicy.validate(
      AccountRoleContext.reimbursementClose(
        receivableAccountId: instruction.receivableAccountId,
        receiveAccountId: instruction.receiveAccountId,
        receivesCash: actual.minorUnits > 0,
      ),
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    final transactionResult = _postingEngine.createReimbursementClose(
      instruction: instruction,
      advance: advance,
      outstanding: outstanding,
      gapIncomeAccountId: gapIncomeAccountId,
    );
    if (transactionResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return _applyPosting(transactionResult.value);
  }

  Future<Result<PostingResult>> _applyPosting(Transaction transaction) async {
    try {
      final accounts = await _accountRepository.findByIds(
        transaction.accountIds,
      );
      final accountMap = {for (final account in accounts) account.id: account};
      final missingFailure = _validateAccountsLoaded(
        transaction.accountIds,
        accountMap,
      );
      if (missingFailure != null) return Result.failure(missingFailure);
      return Result.success(
        PostingResult(
          transaction: transaction,
          accounts: _accountPostingService.apply(
            transaction: transaction,
            accounts: accountMap,
          ),
        ),
      );
    } on Object catch (error) {
      return Result.failure(
        Failure(
          code: 'posting_failed',
          message: 'Failed to close reimbursement.',
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
      if (accounts[accountId] == null) {
        return Failure(
          code: 'account_not_found',
          message: 'Account $accountId does not exist.',
        );
      }
    }
    return null;
  }
}
