import '../../entity/account.dart';
import '../../entity/transaction_group.dart';
import '../../entity/transaction.dart';
import '../../port/account_repository.dart';
import '../../port/transaction_group_repository.dart';
import '../../port/system_account_resolver.dart';
import '../../valobj/ledger_enum.dart';
import '../../valobj/ledger_violation_reason.dart';
import '../../valobj/posting_instruction.dart';
import '../../valobj/posting_result.dart';
import '../account/account_role_policy.dart';
import 'account_posting_service.dart';
import 'posting_engine.dart';

class ReimbursementPostingService {
  const ReimbursementPostingService({
    required TransactionGroupRepository transactionGroupRepository,
    required AccountRepository accountRepository,
    required SystemAccountResolver systemAccountResolver,
    required PostingEngine postingEngine,
    required AccountPostingService accountPostingService,
    required AccountRolePolicy accountRolePolicy,
  }) : _transactionGroupRepository = transactionGroupRepository,
       _accountRepository = accountRepository,
       _systemAccountResolver = systemAccountResolver,
       _postingEngine = postingEngine,
       _accountPostingService = accountPostingService,
       _accountRolePolicy = accountRolePolicy;

  final TransactionGroupRepository _transactionGroupRepository;
  final AccountRepository _accountRepository;
  final SystemAccountResolver _systemAccountResolver;
  final PostingEngine _postingEngine;
  final AccountPostingService _accountPostingService;
  final AccountRolePolicy _accountRolePolicy;

  Future<PostingResult> postAdvance(
    ReimbursementAdvanceInstruction instruction,
  ) async {
    final roleViolation = await _accountRolePolicy.validate(
      AccountRoleContext.reimbursementAdvance(
        receivableAccountId: instruction.receivableAccountId,
        paidFromAccountId: instruction.paidFromAccountId,
        expenseCategoryId: instruction.expenseAccountId,
      ),
    );
    if (roleViolation != null) roleViolation.throwException();

    return _applyPosting(
      _postingEngine.createReimbursementAdvance(instruction),
    );
  }

  Future<PostingResult> postReceipt(
    ReimbursementReceiptInstruction instruction,
  ) async {
    final group = await _loadOpenAdvance(instruction.advanceTransactionId);
    final advance = group.parentTransaction;
    final outstanding =
        advance.primaryAmount - group.reimbursementReceivedTotal();
    if (instruction.amount.minorUnits > outstanding.minorUnits) {
      LedgerViolationReason.reimbursementReceiptExceedsOutstanding
          .throwException();
    }

    final roleViolation = await _accountRolePolicy.validate(
      AccountRoleContext.reimbursementReceipt(
        receivableAccountId: instruction.receivableAccountId,
        receiveAccountId: instruction.receiveAccountId,
      ),
    );
    if (roleViolation != null) roleViolation.throwException();

    return _applyPosting(
      _postingEngine.createReimbursementReceipt(
        instruction: instruction,
        advance: advance,
      ),
    );
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

    final roleViolation = await _accountRolePolicy.validate(
      AccountRoleContext.reimbursementClose(
        receivableAccountId: instruction.receivableAccountId,
        receiveAccountId: instruction.receiveAccountId,
        receivesCash: actual.minorUnits > 0,
      ),
    );
    if (roleViolation != null) roleViolation.throwException();

    return _applyPosting(
      _postingEngine.createReimbursementClose(
        instruction: instruction,
        advance: advance,
        outstanding: outstanding,
        gapIncomeAccountId: gapIncomeAccountId,
      ),
    );
  }

  Future<TransactionGroup> _loadOpenAdvance(String advanceTransactionId) async {
    final group = await _transactionGroupRepository.findByTransactionId(
      advanceTransactionId,
    );
    final advanceViolation = _validateOpenAdvance(group, advanceTransactionId);
    if (advanceViolation != null) advanceViolation.throwException();
    return group!;
  }

  LedgerViolationReason? _validateOpenAdvance(
    TransactionGroup? group,
    String advanceTransactionId,
  ) {
    if (group == null ||
        group.parentTransaction.id != advanceTransactionId ||
        group.parentTransaction.businessPurpose !=
            BusinessPurpose.reimbursementAdvance) {
      return LedgerViolationReason.reimbursementAdvanceNotFound;
    }
    if (group.reimbursementClosed) {
      return LedgerViolationReason.reimbursementAlreadyClosed;
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
