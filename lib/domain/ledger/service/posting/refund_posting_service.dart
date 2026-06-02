import 'package:smartflow/core/error/failure.dart';
import 'package:smartflow/core/result/result.dart';
import '../../entity/account.dart';
import '../../entity/transaction.dart';
import '../../port/account_repository.dart';
import '../../port/root_transaction_group_repository.dart';
import '../../valobj/ledger_enum.dart';
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

  Future<Result<PostingResult>> postRefund(
    RefundInstruction instruction,
  ) async {
    final group = await _rootGroupRepository.findByTransactionId(
      instruction.parentTransactionId,
    );
    if (group == null) {
      return const Result.failure(
        Failure(
          code: 'refund_parent_not_found',
          message: 'Original expense not found.',
        ),
      );
    }
    final parent = group.parentTransaction;
    if (parent.id != instruction.parentTransactionId ||
        (parent.businessPurpose != BusinessPurpose.dailyExpense &&
            parent.businessPurpose != BusinessPurpose.reimbursementAdvance)) {
      return const Result.failure(
        Failure(
          code: 'refund_parent_not_expense',
          message: 'Refund can only be applied to an expense transaction.',
        ),
      );
    }
    if (parent.businessState != BusinessState.current) {
      return const Result.failure(
        Failure(
          code: 'refund_parent_not_current',
          message: 'Refund can only be applied to a current expense.',
        ),
      );
    }
    if (parent.businessPurpose == BusinessPurpose.reimbursementAdvance &&
        group.reimbursementClosed) {
      return const Result.failure(
        Failure(
          code: 'refund_parent_reimbursement_closed',
          message: 'Refund is not supported after reimbursement is closed.',
        ),
      );
    }
    final remaining = parent.primaryAmount - group.refundedTotal();
    if (instruction.amount.minorUnits > remaining.minorUnits) {
      return const Result.failure(
        Failure(
          code: 'refund_exceeds_remaining',
          message: 'Refund exceeds remaining refundable amount.',
        ),
      );
    }

    final parentInstructionResult = _postingInstructionResolver.resolve(parent);
    if (parentInstructionResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final refundOffsetAccountId = resolveRefundOffsetAccountId(
      parentInstructionResult.value,
    );
    if (refundOffsetAccountId == null) {
      return const Result.failure(
        Failure(
          code: 'refund_parent_not_supported',
          message: 'This parent transaction does not support refunds.',
        ),
      );
    }

    final roleFailure = await _accountRolePolicy.validate(
      AccountRoleContext.refund(
        refundToAccountId: instruction.refundToAccountId,
      ),
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    final transactionResult = _postingEngine.createRefund(
      instruction: instruction,
      parent: parent,
      refundOffsetAccountId: refundOffsetAccountId,
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
          message: 'Failed to post refund.',
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
