import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/error/failure.dart';
import 'package:smartflow/core/result/result.dart';

import '../../entity/account.dart';
import '../../entity/root_transaction_group.dart';
import '../../entity/transaction.dart';
import '../../port/account_repository.dart';
import '../../port/root_transaction_group_repository.dart';
import '../../port/system_account_resolver.dart';
import '../../valobj/ledger_enum.dart';
import '../../valobj/ledger_error_code.dart';
import '../../valobj/posting_instruction.dart';
import '../../valobj/posting_result.dart';
import '../account/account_role_policy.dart';
import 'account_posting_service.dart';
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
    return _applyPostingResult(transactionResult.value);
  }

  Future<PostingResult> postReceipt(
    ReimbursementReceiptInstruction instruction,
  ) async {
    final group = await _loadOpenAdvance(instruction.advanceTransactionId);
    final advance = group.parentTransaction;
    final outstanding =
        advance.primaryAmount - group.reimbursementReceivedTotal();
    if (instruction.amount.minorUnits > outstanding.minorUnits) {
      throw _businessException(
        'reimbursement_receipt_exceeds_outstanding',
        'Receipt exceeds outstanding receivable.',
      );
    }

    final roleFailure = await _accountRolePolicy.validate(
      AccountRoleContext.reimbursementReceipt(
        receivableAccountId: instruction.receivableAccountId,
        receiveAccountId: instruction.receiveAccountId,
      ),
    );
    if (roleFailure != null) throw _businessExceptionFromFailure(roleFailure);

    final transactionResult = _postingEngine.createReimbursementReceipt(
      instruction: instruction,
      advance: advance,
    );
    if (transactionResult case FailureResult(:final failure)) {
      throw _businessExceptionFromFailure(failure);
    }
    return _applyPosting(transactionResult.value);
  }

  Future<Result<PostingResult>> postReceiptResult(
    ReimbursementReceiptInstruction instruction,
  ) async {
    try {
      return Result.success(await postReceipt(instruction));
    } on BusinessException catch (exception) {
      return Result.failure(
        Failure(
          code: exception.code,
          message: exception.message,
          cause: exception.cause,
        ),
      );
    }
  }

  Future<PostingResult> close(ReimbursementCloseInstruction instruction) async {
    final group = await _loadOpenAdvance(instruction.advanceTransactionId);
    final advance = group.parentTransaction;
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
    if (roleFailure != null) throw _businessExceptionFromFailure(roleFailure);

    final transactionResult = _postingEngine.createReimbursementClose(
      instruction: instruction,
      advance: advance,
      outstanding: outstanding,
      gapIncomeAccountId: gapIncomeAccountId,
    );
    if (transactionResult case FailureResult(:final failure)) {
      throw _businessExceptionFromFailure(failure);
    }
    return _applyPosting(transactionResult.value);
  }

  Future<Result<PostingResult>> closeResult(
    ReimbursementCloseInstruction instruction,
  ) async {
    try {
      return Result.success(await close(instruction));
    } on BusinessException catch (exception) {
      return Result.failure(
        Failure(
          code: exception.code,
          message: exception.message,
          cause: exception.cause,
        ),
      );
    }
  }

  Future<PostingResult> _applyPosting(Transaction transaction) async {
    final accounts = await _accountRepository.findByIds(transaction.accountIds);
    final accountMap = {for (final account in accounts) account.id: account};
    final missingFailure = _validateAccountsLoaded(
      transaction.accountIds,
      accountMap,
    );
    if (missingFailure != null) {
      throw _businessExceptionFromFailure(missingFailure);
    }
    return PostingResult(
      transaction: transaction,
      accounts: _accountPostingService.apply(
        transaction: transaction,
        accounts: accountMap,
      ),
    );
  }

  Future<Result<PostingResult>> _applyPostingResult(
    Transaction transaction,
  ) async {
    try {
      return Result.success(await _applyPosting(transaction));
    } on BusinessException catch (exception) {
      return Result.failure(
        Failure(
          code: exception.code,
          message: exception.message,
          cause: exception.cause,
        ),
      );
    }
  }

  Future<RootTransactionGroup> _loadOpenAdvance(
    String advanceTransactionId,
  ) async {
    final group = await _rootGroupRepository.findByTransactionId(
      advanceTransactionId,
    );
    if (group == null ||
        group.parentTransaction.id != advanceTransactionId ||
        group.parentTransaction.businessPurpose !=
            BusinessPurpose.reimbursementAdvance) {
      throw _businessException(
        'reimbursement_advance_not_found',
        'Reimbursement advance not found.',
      );
    }
    final advance = group.parentTransaction;
    if (advance.businessState != BusinessState.current) {
      throw _businessException(
        'reimbursement_advance_not_current',
        'Reimbursement advance is not current.',
      );
    }
    if (group.reimbursementClosed) {
      throw _businessException(
        'reimbursement_already_closed',
        'This reimbursement chain is already closed.',
      );
    }
    return group;
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

  BusinessException _businessException(String code, String message) {
    return _businessExceptionFromFailure(Failure(code: code, message: message));
  }

  BusinessException _businessExceptionFromFailure(Failure failure) {
    return BusinessException(
      switch (failure.code) {
        'account_not_found' => LedgerErrorCode.accountNotFound,
        'account_role_invalid' => LedgerErrorCode.accountInvalidRole,
        'account_subtype_invalid' => LedgerErrorCode.accountInvalidRole,
        'reimbursement_advance_not_found' =>
          LedgerErrorCode.transactionNotFound,
        'reimbursement_advance_not_current' =>
          LedgerErrorCode.transactionNotEditable,
        'reimbursement_already_closed' =>
          LedgerErrorCode.transactionNotEditable,
        'reimbursement_receipt_exceeds_outstanding' =>
          LedgerErrorCode.transactionInvalidCommand,
        'reimbursement_amount_not_positive' =>
          LedgerErrorCode.transactionInvalidCommand,
        'reimbursement_close_amount_negative' =>
          LedgerErrorCode.transactionInvalidCommand,
        'reimbursement_gap_income_required' =>
          LedgerErrorCode.transactionPostingFailed,
        _ => LedgerErrorCode.transactionPostingFailed,
      },
      message: failure.message,
      cause: failure.cause,
    );
  }
}
