import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/error/failure.dart';
import 'package:smartflow/core/result/result.dart';

import '../../entity/account.dart';
import '../../entity/transaction.dart';
import '../../port/account_repository.dart';
import '../../port/root_transaction_group_repository.dart';
import '../../valobj/ledger_enum.dart';
import '../../valobj/ledger_error_code.dart';
import '../../valobj/posting_instruction.dart';
import '../../valobj/posting_result.dart';
import '../account/account_role_policy.dart';
import 'account_posting_service.dart';
import 'posting_engine.dart';
import 'posting_instruction_resolver.dart';

class RefundPostingService {
  const RefundPostingService({
    required RootTransactionGroupRepository rootGroupRepository,
    required AccountRepository accountRepository,
    required PostingInstructionResolver postingInstructionResolver,
    required PostingEngine postingEngine,
    required AccountPostingService accountPostingService,
    required AccountRolePolicy accountRolePolicy,
  }) : _rootGroupRepository = rootGroupRepository,
       _accountRepository = accountRepository,
       _postingInstructionResolver = postingInstructionResolver,
       _postingEngine = postingEngine,
       _accountPostingService = accountPostingService,
       _accountRolePolicy = accountRolePolicy;

  final RootTransactionGroupRepository _rootGroupRepository;
  final AccountRepository _accountRepository;
  final PostingInstructionResolver _postingInstructionResolver;
  final PostingEngine _postingEngine;
  final AccountPostingService _accountPostingService;
  final AccountRolePolicy _accountRolePolicy;

  Future<PostingResult> postRefund(RefundInstruction instruction) async {
    final group = await _rootGroupRepository.findByTransactionId(
      instruction.parentTransactionId,
    );
    if (group == null) {
      throw _businessException(
        'refund_parent_not_found',
        'Original expense not found.',
      );
    }

    final parent = group.parentTransaction;
    if (parent.id != instruction.parentTransactionId ||
        (parent.businessPurpose != BusinessPurpose.dailyExpense &&
            parent.businessPurpose != BusinessPurpose.reimbursementAdvance)) {
      throw _businessException(
        'refund_parent_not_expense',
        'Refund can only be applied to an expense transaction.',
      );
    }
    if (parent.businessState != BusinessState.current) {
      throw _businessException(
        'refund_parent_not_current',
        'Refund can only be applied to a current expense.',
      );
    }
    if (parent.businessPurpose == BusinessPurpose.reimbursementAdvance &&
        group.reimbursementClosed) {
      throw _businessException(
        'refund_parent_reimbursement_closed',
        'Refund is not supported after reimbursement is closed.',
      );
    }
    final remaining = parent.primaryAmount - group.refundedTotal();
    if (instruction.amount.minorUnits > remaining.minorUnits) {
      throw _businessException(
        'refund_exceeds_remaining',
        'Refund exceeds remaining refundable amount.',
      );
    }

    final parentInstructionResult = _postingInstructionResolver.resolve(parent);
    if (parentInstructionResult case FailureResult(:final failure)) {
      throw _businessExceptionFromFailure(failure);
    }
    final refundOffsetAccountId = resolveRefundOffsetAccountId(
      parentInstructionResult.value,
    );
    if (refundOffsetAccountId == null) {
      throw _businessException(
        'refund_parent_not_supported',
        'This parent transaction does not support refunds.',
      );
    }

    final roleFailure = await _accountRolePolicy.validate(
      AccountRoleContext.refund(
        refundToAccountId: instruction.refundToAccountId,
      ),
    );
    if (roleFailure != null) throw _businessExceptionFromFailure(roleFailure);

    final transactionResult = _postingEngine.createRefund(
      instruction: instruction,
      parent: parent,
      refundOffsetAccountId: refundOffsetAccountId,
    );
    if (transactionResult case FailureResult(:final failure)) {
      throw _businessExceptionFromFailure(failure);
    }
    return _applyPosting(transactionResult.value);
  }

  Future<Result<PostingResult>> postRefundResult(
    RefundInstruction instruction,
  ) async {
    try {
      return Result.success(await postRefund(instruction));
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
        'refund_parent_not_found' => LedgerErrorCode.transactionNotFound,
        'refund_parent_not_expense' => LedgerErrorCode.transactionNotEditable,
        'refund_parent_not_current' => LedgerErrorCode.transactionNotEditable,
        'refund_parent_reimbursement_closed' =>
          LedgerErrorCode.transactionNotEditable,
        'refund_exceeds_remaining' => LedgerErrorCode.transactionInvalidCommand,
        'refund_parent_not_supported' => LedgerErrorCode.transactionNotEditable,
        'refund_amount_not_positive' =>
          LedgerErrorCode.transactionInvalidCommand,
        _ => LedgerErrorCode.transactionPostingFailed,
      },
      message: failure.message,
      cause: failure.cause,
    );
  }
}
