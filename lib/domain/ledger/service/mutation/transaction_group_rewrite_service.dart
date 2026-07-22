import 'package:smartflow/core/money/money.dart';
import '../../entity/account.dart';
import '../../entity/transaction_group.dart';
import '../../entity/transaction.dart';
import '../../port/account_repository.dart';
import '../../port/transaction_group_repository.dart';
import '../../port/system_account_resolver.dart';
import '../../valobj/ledger_enum.dart';
import '../../valobj/ledger_violation_reason.dart';
import '../../valobj/posting_instruction.dart';
import '../account/account_role_policy.dart';
import '../posting/account_posting_service.dart';
import '../posting/ledger_posting_service.dart';
import '../posting/posting_engine.dart';
import '../posting/posting_instruction_resolver.dart';
import 'transaction_group_rewrite_planner.dart';
import 'transaction_group_rewrite_plan.dart';
import 'transaction_group_rewrite_result.dart';
import 'transaction_deletion_result.dart';

class TransactionGroupRewriteService {
  TransactionGroupRewriteService({
    required TransactionGroupRepository transactionGroupRepository,
    required AccountRepository accountRepository,
    required PostingInstructionResolver postingInstructionResolver,
    required PostingEngine postingEngine,
    required AccountPostingService accountPostingService,
    required AccountRolePolicy accountRolePolicy,
    required SystemAccountResolver systemAccountResolver,
    TransactionGroupRewritePlanner? rewritePlanner,
    LedgerPostingService? postingService,
  }) : _transactionGroupRepository = transactionGroupRepository,
       _accountRepository = accountRepository,
       _postingInstructionResolver = postingInstructionResolver,
       _postingEngine = postingEngine,
       _accountPostingService = accountPostingService,
       _accountRolePolicy = accountRolePolicy,
       _systemAccountResolver = systemAccountResolver,
       _postingService =
           postingService ??
           LedgerPostingService(
             accountRepository: accountRepository,
             systemAccountResolver: systemAccountResolver,
             postingEngine: postingEngine,
             accountPostingService: accountPostingService,
             accountRolePolicy: accountRolePolicy,
           ),
       _rewritePlanner =
           rewritePlanner ??
           TransactionGroupRewritePlanner(
             postingEngine: postingEngine,
             postingInstructionResolver: postingInstructionResolver,
           );

  final TransactionGroupRepository _transactionGroupRepository;
  final AccountRepository _accountRepository;
  final PostingInstructionResolver _postingInstructionResolver;
  final PostingEngine _postingEngine;
  final AccountPostingService _accountPostingService;
  final AccountRolePolicy _accountRolePolicy;
  final SystemAccountResolver _systemAccountResolver;
  final LedgerPostingService _postingService;
  final TransactionGroupRewritePlanner _rewritePlanner;

  Future<TransactionGroupRewriteResult> rewriteParentTransaction(
    EditParentTransactionInstruction instruction,
  ) async {
    final rootGroup = await _transactionGroupRepository.findByTransactionId(
      instruction.transactionId,
    );
    final targetViolation = _validateParentEditTarget(rootGroup, instruction);
    if (targetViolation != null) targetViolation.throwException();

    final currentGroup = _currentGroup(rootGroup!);
    final currentParent = currentGroup.parentTransaction;
    final currentInstruction = _postingInstructionResolver.resolve(
      currentParent,
    );
    final editedInstruction = instruction.editPatch.applyTo(currentInstruction);
    final candidateParent = await _postingService.createCandidate(
      editedInstruction,
    );
    candidateParent.updateBasicInfo(
      occurredAt: instruction.occurredAt,
      counterpartyName: instruction.counterpartyName,
      note: instruction.note,
    );
    if (candidateParent.businessPurpose ==
        BusinessPurpose.reimbursementAdvance) {
      candidateParent.updateReportingFlags(
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
        parentPurpose: BusinessPurpose.dailyExpense,
      );
    } else {
      candidateParent.updateReportingFlags(
        isExcludedFromStats: instruction.isExcludedFromStats,
        isExcludedFromBudget: instruction.isExcludedFromBudget,
        parentPurpose: candidateParent.businessPurpose,
      );
    }

    final plan = await _rewritePlanner.planParentRewrite(
      currentGroup: currentGroup,
      candidateParent: candidateParent,
    );
    final accounts = await _loadAccountsFor([
      for (final rewrite in plan.rewrites) rewrite.before,
      for (final rewrite in plan.rewrites) rewrite.after,
    ]);
    final changedAccounts = _accountPostingService.applyRewrite(
      before: plan.rewrites.map((rewrite) => rewrite.before),
      after: plan.rewrites.map((rewrite) => rewrite.after),
      accounts: accounts,
    );
    return TransactionGroupRewriteResult(
      plan: plan,
      accounts: changedAccounts,
      currentTransaction: plan.currentGroup.parentTransaction,
    );
  }

  Future<TransactionGroupRewriteResult> rewriteRefundTransaction(
    EditRefundTransactionInstruction instruction,
  ) async {
    final rootGroup = await _transactionGroupRepository.findByTransactionId(
      instruction.transactionId,
    );
    if (rootGroup == null) {
      LedgerViolationReason.transactionNotFound.throwException();
    }
    final group = _currentGroup(rootGroup);
    final currentRefund = group.findTransaction(instruction.transactionId);
    if (currentRefund == null ||
        currentRefund.id == group.parentTransaction.id ||
        currentRefund.businessPurpose != BusinessPurpose.refund) {
      LedgerViolationReason.refundTransactionRequired.throwException();
    }
    if (group.reimbursementClosed) {
      LedgerViolationReason.reimbursementAlreadyClosed.throwException();
    }
    final currentInstruction = _postingInstructionResolver.resolveRefund(
      currentRefund,
    );
    final editedInstruction = instruction.editPatch.applyTo(currentInstruction);
    final remaining =
        group.parentTransaction.businessPurpose ==
                BusinessPurpose.reimbursementAdvance
            ? group.reimbursementOutstanding() + currentRefund.primaryAmount
            : group.parentTransaction.primaryAmount -
                group.refundedTotal() +
                currentRefund.primaryAmount;
    if (editedInstruction.amount.minorUnits > remaining.minorUnits) {
      LedgerViolationReason.refundExceedsRemaining.throwException();
    }
    final parentInstruction = _postingInstructionResolver.resolve(
      group.parentTransaction,
    );
    final offsetAccountId = resolveRefundOffsetAccountId(parentInstruction);
    if (offsetAccountId == null) {
      LedgerViolationReason.refundParentNotSupported.throwException();
    }
    final roleViolation = await _accountRolePolicy.validate(
      AccountRoleContext.refund(
        refundToAccountId: editedInstruction.refundToAccountId,
      ),
    );
    if (roleViolation != null) roleViolation.throwException();
    final candidate = _postingEngine.createRefund(
      instruction: editedInstruction,
      parent: group.parentTransaction,
      refundOffsetAccountId: offsetAccountId,
    );
    final rewritten = _preserveIdentity(
      original: currentRefund,
      candidate: candidate,
    );
    rewritten.updateBasicInfo(
      occurredAt: instruction.occurredAt,
      counterpartyName: instruction.counterpartyName,
      note: instruction.note,
    );
    return _singleChildRewrite(
      group: group,
      original: currentRefund,
      rewritten: rewritten,
    );
  }

  Future<TransactionGroupRewriteResult> rewriteReimbursementReceipt(
    EditReimbursementReceiptTransactionInstruction instruction,
  ) async {
    final target = await _loadReimbursementChild(
      transactionId: instruction.transactionId,
      purpose: BusinessPurpose.reimbursementReceipt,
      targetViolation:
          LedgerViolationReason.reimbursementReceiptTransactionRequired,
      requireOpenGroup: true,
    );
    final group = target.group;
    final currentReceipt = target.child;
    final remaining =
        group.reimbursementOutstanding() + currentReceipt.primaryAmount;
    final amount = instruction.amount ?? currentReceipt.primaryAmount;
    if (amount.minorUnits > remaining.minorUnits) {
      LedgerViolationReason.reimbursementReceiptExceedsOutstanding
          .throwException();
    }
    final accounts = _resolveReimbursementAccounts(
      child: currentReceipt,
      receiveAccountId: instruction.receiveAccountId,
      receivableAccountId: instruction.receivableAccountId,
      unresolvedViolation:
          LedgerViolationReason.reimbursementReceiptAccountsUnresolved,
    );
    final roleViolation = await _accountRolePolicy.validate(
      AccountRoleContext.reimbursementReceipt(
        receivableAccountId: accounts.receivableAccountId,
        receiveAccountId: accounts.receiveAccountId,
      ),
    );
    if (roleViolation != null) roleViolation.throwException();
    final candidate = _postingEngine.createReimbursementReceipt(
      instruction: ReimbursementReceiptInstruction(
        advanceTransactionId: group.parentTransaction.id,
        amount: amount,
        receivableAccountId: accounts.receivableAccountId,
        receiveAccountId: accounts.receiveAccountId,
        occurredAt: currentReceipt.occurredAt,
        counterpartyName: currentReceipt.counterpartyName,
        note: currentReceipt.note,
      ),
      advance: group.parentTransaction,
    );
    final rewritten = _preserveIdentity(
      original: currentReceipt,
      candidate: candidate,
    );
    rewritten.updateBasicInfo(
      occurredAt: instruction.occurredAt,
      counterpartyName: instruction.counterpartyName,
      note: instruction.note,
    );
    return _singleChildRewrite(
      group: group,
      original: currentReceipt,
      rewritten: rewritten,
    );
  }

  Future<TransactionGroupRewriteResult> rewriteReimbursementClose(
    EditReimbursementCloseTransactionInstruction instruction,
  ) async {
    final target = await _loadReimbursementChild(
      transactionId: instruction.transactionId,
      purpose: BusinessPurpose.reimbursementClose,
      targetViolation:
          LedgerViolationReason.reimbursementCloseTransactionRequired,
      requireOpenGroup: false,
    );
    final group = target.group;
    final currentClose = target.child;
    final outstanding =
        _detailAmount(
          currentClose,
          TransactionDetailType.reimbursementCloseMain,
        ) ??
        Money.zero();
    final actual =
        instruction.actualReceivedAmount ??
        _reimbursementCloseActualAmount(currentClose);
    final accounts = _resolveReimbursementAccounts(
      child: currentClose,
      receiveAccountId: instruction.receiveAccountId,
      receivableAccountId: instruction.receivableAccountId,
      unresolvedViolation:
          LedgerViolationReason.reimbursementCloseAccountsUnresolved,
    );
    final gapIncomeAccountId =
        actual.minorUnits > outstanding.minorUnits
            ? await _systemAccountResolver.resolveReimbursementGapIncome()
            : null;
    final roleViolation = await _accountRolePolicy.validate(
      AccountRoleContext.reimbursementClose(
        receivableAccountId: accounts.receivableAccountId,
        receiveAccountId: accounts.receiveAccountId,
        receivesCash: actual.minorUnits > 0,
      ),
    );
    if (roleViolation != null) roleViolation.throwException();
    final candidate = _postingEngine.createReimbursementClose(
      instruction: ReimbursementCloseInstruction(
        advanceTransactionId: group.parentTransaction.id,
        actualReceivedAmount: actual,
        receivableAccountId: accounts.receivableAccountId,
        receiveAccountId: accounts.receiveAccountId,
        occurredAt: currentClose.occurredAt,
        counterpartyName: currentClose.counterpartyName,
        note: currentClose.note,
      ),
      advance: group.parentTransaction,
      outstanding: outstanding,
      gapIncomeAccountId: gapIncomeAccountId,
    );
    final rewritten = _preserveIdentity(
      original: currentClose,
      candidate: candidate,
    );
    rewritten.updateBasicInfo(
      occurredAt: instruction.occurredAt,
      counterpartyName: instruction.counterpartyName,
      note: instruction.note,
    );
    return _singleChildRewrite(
      group: group,
      original: currentClose,
      rewritten: rewritten,
    );
  }

  Future<TransactionDeletionResult> deleteCurrentTransaction(
    String transactionId,
  ) async {
    final rootGroup = await _transactionGroupRepository.findByTransactionId(
      transactionId,
    );
    if (rootGroup == null) {
      LedgerViolationReason.transactionNotFound.throwException();
    }
    final group = _currentGroup(rootGroup);
    final target = group.findTransaction(transactionId);
    if (target == null) {
      LedgerViolationReason.transactionNotFound.throwException();
    }
    if (target.id != group.parentTransaction.id &&
        group.reimbursementClosed &&
        target.businessPurpose != BusinessPurpose.reimbursementClose) {
      LedgerViolationReason.reimbursementAlreadyClosed.throwException();
    }
    final deleted =
        target.id == group.parentTransaction.id
            ? group.transactions.toList()
            : [target];
    final accounts = await _loadAccountsFor(deleted);
    final changedAccounts = _accountPostingService.removeAll(
      transactions: deleted,
      accounts: accounts,
    );
    return TransactionDeletionResult(
      targetTransactionId: target.id,
      deletesGroup: target.id == group.parentTransaction.id,
      deletedTransactions: deleted,
      accounts: changedAccounts,
    );
  }

  Future<Map<String, Account>> _loadAccountsFor(
    Iterable<Transaction> transactions,
  ) async {
    final ids = {
      for (final transaction in transactions) ...transaction.accountIds,
    };
    final accounts = await _accountRepository.findByIds(ids);
    return {for (final account in accounts) account.id: account};
  }

  Future<({TransactionGroup group, Transaction child})>
  _loadReimbursementChild({
    required String transactionId,
    required BusinessPurpose purpose,
    required LedgerViolationReason targetViolation,
    required bool requireOpenGroup,
  }) async {
    final rootGroup = await _transactionGroupRepository.findByTransactionId(
      transactionId,
    );
    if (rootGroup == null) {
      LedgerViolationReason.transactionNotFound.throwException();
    }
    final group = _currentGroup(rootGroup);
    final child = group.findTransaction(transactionId);
    if (child == null ||
        child.id == group.parentTransaction.id ||
        child.businessPurpose != purpose) {
      targetViolation.throwException();
    }
    if (requireOpenGroup && group.reimbursementClosed) {
      LedgerViolationReason.reimbursementAlreadyClosed.throwException();
    }
    final advanceViolation = _validateReimbursementAdvance(rootGroup);
    if (advanceViolation != null) advanceViolation.throwException();
    return (group: group, child: child);
  }

  ({String receiveAccountId, String receivableAccountId})
  _resolveReimbursementAccounts({
    required Transaction child,
    required String? receiveAccountId,
    required String? receivableAccountId,
    required LedgerViolationReason unresolvedViolation,
  }) {
    final resolvedReceiveAccountId =
        receiveAccountId ?? _firstEntryAccount(child, EntryDirection.debit);
    final resolvedReceivableAccountId =
        receivableAccountId ?? _firstEntryAccount(child, EntryDirection.credit);
    if (resolvedReceiveAccountId == null ||
        resolvedReceivableAccountId == null) {
      unresolvedViolation.throwException();
    }
    return (
      receiveAccountId: resolvedReceiveAccountId,
      receivableAccountId: resolvedReceivableAccountId,
    );
  }

  TransactionGroup _currentGroup(TransactionGroup group) {
    return TransactionGroup(
      parentTransaction: group.parentTransaction,
      childTransactions: group.childTransactions,
    );
  }

  Transaction _preserveIdentity({
    required Transaction original,
    required Transaction candidate,
  }) {
    return candidate.copyWith(
      id: original.id,
      postedAt: original.postedAt,
      parentTransactionId: original.parentTransactionId,
      sourceKind: original.sourceKind,
      ownership: original.ownership,
      isExcludedFromStats: original.isExcludedFromStats,
      isExcludedFromBudget: original.isExcludedFromBudget,
    );
  }

  Future<TransactionGroupRewriteResult> _singleChildRewrite({
    required TransactionGroup group,
    required Transaction original,
    required Transaction rewritten,
  }) async {
    final accountingExpressionChanged =
        !original.hasSameAccountingExpressionAs(rewritten);
    final plan = TransactionGroupRewritePlan(
      rewrites:
          accountingExpressionChanged
              ? [TransactionRewrite(before: original, after: rewritten)]
              : const [],
      rowUpdates: accountingExpressionChanged ? const [] : [rewritten],
      currentGroup: TransactionGroup(
        parentTransaction: group.parentTransaction,
        childTransactions: [
          for (final child in group.childTransactions)
            child.id == original.id ? rewritten : child,
        ],
      ),
    );
    final changedAccounts =
        accountingExpressionChanged
            ? _accountPostingService.applyRewrite(
              before: [original],
              after: [rewritten],
              accounts: await _loadAccountsFor([original, rewritten]),
            )
            : const <Account>[];
    return TransactionGroupRewriteResult(
      plan: plan,
      accounts: changedAccounts,
      currentTransaction: rewritten,
    );
  }

  String? _firstEntryAccount(
    Transaction transaction,
    EntryDirection direction,
  ) {
    for (final entry in transaction.entries) {
      if (entry.direction == direction) return entry.accountId;
    }
    return null;
  }

  LedgerViolationReason? _validateParentEditTarget(
    TransactionGroup? group,
    EditParentTransactionInstruction instruction,
  ) {
    if (group == null) {
      return LedgerViolationReason.transactionNotFound;
    }
    final currentParent = group.parentTransaction;
    if (instruction.transactionId != currentParent.id) {
      return LedgerViolationReason.parentTransactionRequired;
    }
    return null;
  }

  LedgerViolationReason? _validateReimbursementAdvance(TransactionGroup group) {
    final advance = group.parentTransaction;
    if (advance.businessPurpose != BusinessPurpose.reimbursementAdvance) {
      return LedgerViolationReason.reimbursementParentNotAdvance;
    }
    return null;
  }

  Money? _detailAmount(Transaction transaction, TransactionDetailType type) {
    for (final detail in transaction.details) {
      if (detail.type == type) return detail.amount;
    }
    return null;
  }

  Money _reimbursementCloseActualAmount(Transaction transaction) {
    final outstanding =
        _detailAmount(
          transaction,
          TransactionDetailType.reimbursementCloseMain,
        ) ??
        Money.zero();
    final gapIncome =
        _detailAmount(
          transaction,
          TransactionDetailType.reimbursementGapIncome,
        ) ??
        Money.zero();
    final gapExpense =
        _detailAmount(
          transaction,
          TransactionDetailType.reimbursementGapExpense,
        ) ??
        Money.zero();
    return outstanding + gapIncome - gapExpense;
  }
}
