import '../../entity/account.dart';
import '../../entity/transaction_group.dart';
import '../../entity/transaction.dart';
import 'package:smartflow/core/money/money.dart';
import '../../port/account_repository.dart';
import '../../port/transaction_group_repository.dart';
import '../../port/system_account_resolver.dart';
import '../../valobj/ledger_enum.dart';
import '../../valobj/account_amount_allocation.dart';
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
        paidFromAccountIds: instruction.settlementAllocations.map(
          (allocation) => allocation.accountId,
        ),
        expenseCategoryIds: instruction.categoryAllocations.map(
          (allocation) => allocation.accountId,
        ),
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
    final outstanding = group.reimbursementOutstanding();
    if (instruction.amount.minorUnits > outstanding.minorUnits) {
      LedgerViolationReason.reimbursementReceiptExceedsOutstanding
          .throwException();
    }

    final roleViolation = await _accountRolePolicy.validate(
      AccountRoleContext.reimbursementReceipt(
        receivableAccountId: instruction.receivableAccountId,
        receiveAccountIds: instruction.settlementAllocations.map(
          (allocation) => allocation.accountId,
        ),
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
    final outstanding = group.reimbursementOutstanding();
    final actual = instruction.actualReceivedAmount;
    final gapIncomeAccountId = actual.minorUnits > outstanding.minorUnits
        ? await _systemAccountResolver.resolveReimbursementGapIncome()
        : null;
    final gapExpenseAllocations = _gapExpenseAllocations(
      instruction: instruction,
      group: group,
      outstanding: outstanding,
    );
    if (!group.allocationsFitRefundableCategories(gapExpenseAllocations)) {
      LedgerViolationReason.allocationExceedsAvailable.throwException();
    }
    final normalizedInstruction = ReimbursementCloseInstruction(
      advanceTransactionId: instruction.advanceTransactionId,
      actualReceivedAmount: instruction.actualReceivedAmount,
      receivableAccountId: instruction.receivableAccountId,
      settlementAllocations: instruction.settlementAllocations,
      gapExpenseAllocations: gapExpenseAllocations,
      occurredAt: instruction.occurredAt,
      postedAt: instruction.postedAt,
      counterpartyName: instruction.counterpartyName,
      note: instruction.note,
    );

    final roleViolation = await _accountRolePolicy.validate(
      AccountRoleContext.reimbursementClose(
        receivableAccountId: instruction.receivableAccountId,
        receiveAccountIds: instruction.settlementAllocations.map(
          (allocation) => allocation.accountId,
        ),
        gapExpenseCategoryIds: gapExpenseAllocations.map(
          (allocation) => allocation.accountId,
        ),
        receivesCash: actual.minorUnits > 0,
      ),
    );
    if (roleViolation != null) roleViolation.throwException();

    return _applyPosting(
      _postingEngine.createReimbursementClose(
        instruction: normalizedInstruction,
        advance: advance,
        outstanding: outstanding,
        gapIncomeAccountId: gapIncomeAccountId,
      ),
    );
  }

  List<AccountAmountAllocation> _gapExpenseAllocations({
    required ReimbursementCloseInstruction instruction,
    required TransactionGroup group,
    required Money outstanding,
  }) {
    final shortfall = outstanding - instruction.actualReceivedAmount;
    if (shortfall.minorUnits <= 0) return const [];
    if (instruction.gapExpenseAllocations.isNotEmpty) {
      return instruction.gapExpenseAllocations;
    }
    final remaining = group.remainingRefundableCategoryAllocations();
    if (remaining.length != 1) {
      LedgerViolationReason.allocationRequired.throwException(
        message: 'Gap expense category allocations are required.',
      );
    }
    return [remaining.single.copyWith(amount: shortfall)];
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
