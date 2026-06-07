import '../../entity/account.dart';
import '../../entity/root_transaction_group.dart';
import '../../entity/transaction.dart';
import '../../port/account_repository.dart';
import '../../port/root_transaction_group_repository.dart';
import '../../valobj/ledger_enum.dart';
import '../../valobj/ledger_violation_reason.dart';
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
      LedgerViolationReason.refundParentNotFound.throwException();
    }

    final parent = group.parentTransaction;
    final parentViolation = _validateRefundParent(parent, group, instruction);
    if (parentViolation != null) parentViolation.throwException();

    final remaining = parent.primaryAmount - group.refundedTotal();
    if (instruction.amount.minorUnits > remaining.minorUnits) {
      LedgerViolationReason.refundExceedsRemaining.throwException();
    }

    final parentInstruction = _postingInstructionResolver.resolve(parent);
    final refundOffsetAccountId = resolveRefundOffsetAccountId(
      parentInstruction,
    );
    if (refundOffsetAccountId == null) {
      LedgerViolationReason.refundParentNotSupported.throwException();
    }

    final roleViolation = await _accountRolePolicy.validate(
      AccountRoleContext.refund(
        refundToAccountId: instruction.refundToAccountId,
      ),
    );
    if (roleViolation != null) roleViolation.throwException();

    final transaction = _postingEngine.createRefund(
      instruction: instruction,
      parent: parent,
      refundOffsetAccountId: refundOffsetAccountId,
    );
    return _applyPosting(transaction);
  }

  LedgerViolationReason? _validateRefundParent(
    Transaction parent,
    RootTransactionGroup group,
    RefundInstruction instruction,
  ) {
    if (parent.id != instruction.parentTransactionId ||
        (parent.businessPurpose != BusinessPurpose.dailyExpense &&
            parent.businessPurpose != BusinessPurpose.reimbursementAdvance)) {
      return LedgerViolationReason.refundParentNotExpense;
    }
    if (parent.businessState != BusinessState.current) {
      return LedgerViolationReason.refundParentNotCurrent;
    }
    if (parent.businessPurpose == BusinessPurpose.reimbursementAdvance &&
        group.reimbursementClosed) {
      return LedgerViolationReason.refundParentReimbursementClosed;
    }
    return null;
  }

  Future<PostingResult> _applyPosting(Transaction transaction) async {
    final accounts = await _accountRepository.findByIds(transaction.accountIds);
    final accountMap = {for (final account in accounts) account.id: account};
    final accountViolation = _validateAccountsLoaded(
      transaction.accountIds,
      accountMap,
    );
    if (accountViolation != null) accountViolation.throwException();
    return PostingResult(
      transaction: transaction,
      accounts: _accountPostingService.apply(
        transaction: transaction,
        accounts: accountMap,
      ),
    );
  }

  LedgerViolationReason? _validateAccountsLoaded(
    Set<String> accountIds,
    Map<String, Account> accounts,
  ) {
    for (final accountId in accountIds) {
      final account = accounts[accountId];
      if (account == null) return LedgerViolationReason.accountNotFound;
      if (account.archivedAt != null) {
        return LedgerViolationReason.accountArchived;
      }
    }
    return null;
  }
}
