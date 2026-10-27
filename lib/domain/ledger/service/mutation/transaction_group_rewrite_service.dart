import 'package:smartflow/core/money/money.dart';
import '../../entity/account.dart';
import '../../entity/transaction_group.dart';
import '../../entity/transaction.dart';
import '../../port/account_repository.dart';
import '../../port/transaction_group_repository.dart';
import '../../port/system_account_resolver.dart';
import '../../valobj/ledger_enum.dart';
import '../../valobj/account_amount_allocation.dart';
import '../../valobj/ledger_violation_reason.dart';
import '../../valobj/posting_instruction.dart';
import '../../valobj/transaction_ownership.dart';
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
             systemAccountResolver: systemAccountResolver,
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
      reducibleBalanceOverrides: await _reducibleBalanceOverrides(
        currentInstruction,
      ),
    );
    candidateParent.updateBasicInfo(
      occurredAt: instruction.occurredAt,
      counterpartyId: instruction.counterpartyId,
      note: instruction.note,
    );
    candidateParent.updateReportingFlags(
      isExcludedFromStats:
          instruction.isExcludedFromStats ?? currentParent.isExcludedFromStats,
      isExcludedFromBudget:
          instruction.isExcludedFromBudget ??
          currentParent.isExcludedFromBudget,
    );

    final plan = await _rewritePlanner.planParentRewrite(
      currentGroup: currentGroup,
      candidateParent: candidateParent,
      refundSelfBorneAllocations: instruction.refundSelfBorneAllocations,
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

  Future<Map<String, Money>> _reducibleBalanceOverrides(
    PostingInstruction current,
  ) async {
    final (accountId, amount) = switch (current) {
      BadDebtInstruction(:final receivableAccountId, :final amount) => (
        receivableAccountId,
        amount,
      ),
      DebtReliefInstruction(:final liabilityAccountId, :final amount) => (
        liabilityAccountId,
        amount,
      ),
      _ => (null, null),
    };
    if (accountId == null || amount == null) return const {};
    final account = await _accountRepository.findById(accountId);
    if (account == null) return const {};
    return {
      accountId: Money(
        minorUnits: account.balance.minorUnits + amount.minorUnits,
      ),
    };
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
    final currentInstruction = _postingInstructionResolver.resolveRefund(
      currentRefund,
    );
    final editedInstruction = instruction.editPatch.applyTo(currentInstruction);
    if (group.advanceSettled &&
        (editedInstruction.amount != currentInstruction.amount ||
            !allocationsFitAvailable(
              requested: editedInstruction.categoryAllocations,
              available: currentInstruction.categoryAllocations,
            ) ||
            !allocationsFitAvailable(
              requested: currentInstruction.categoryAllocations,
              available: editedInstruction.categoryAllocations,
            ))) {
      LedgerViolationReason.advanceAlreadyClosed.throwException();
    }
    final remaining =
        group.parentTransaction.primaryAmount -
        group.refundedTotal() +
        currentRefund.primaryAmount;
    if (editedInstruction.amount.minorUnits > remaining.minorUnits) {
      LedgerViolationReason.refundExceedsRemaining.throwException();
    }
    if (!group.allocationsFitRefundableCategories(
      editedInstruction.categoryAllocations,
      excludingTransactionId: currentRefund.id,
    )) {
      LedgerViolationReason.allocationExceedsAvailable.throwException();
    }
    final roleViolation = await _accountRolePolicy.validate(
      AccountRoleContext.refund(
        refundToAccountIds: editedInstruction.settlementAllocations.map(
          (allocation) => allocation.accountId,
        ),
        categoryAccountIds: editedInstruction.categoryAllocations.map(
          (allocation) => allocation.accountId,
        ),
      ),
    );
    if (roleViolation != null) roleViolation.throwException();
    final candidate = _postingEngine.createRefund(
      instruction: RefundInstruction(
        parentTransactionId: editedInstruction.parentTransactionId,
        amount: editedInstruction.amount,
        categoryAllocations: editedInstruction.categoryAllocations,
        selfBorneAllocations: editedInstruction.selfBorneAllocations,
        settlementAllocations: editedInstruction.settlementAllocations,
        occurredAt: editedInstruction.occurredAt,
        postedAt: editedInstruction.postedAt,
        counterpartyId: editedInstruction.counterpartyId,
        note: editedInstruction.note,
      ),
      parent: group.parentTransaction,
    );
    final rewritten = _preserveIdentity(
      original: currentRefund,
      candidate: candidate,
    );
    rewritten.updateBasicInfo(
      occurredAt: instruction.occurredAt,
      counterpartyId: instruction.counterpartyId,
      note: instruction.note,
    );
    return _singleChildRewrite(
      group: group,
      original: currentRefund,
      rewritten: rewritten,
    );
  }

  Future<TransactionGroupRewriteResult> rewriteAdvanceCollection(
    EditAdvanceCollectionTransactionInstruction instruction,
  ) async {
    final rootGroup = await _loadRootGroup(instruction.transactionId);
    if (_isAccountManagedTopLevel(
      rootGroup,
      transactionId: instruction.transactionId,
      purpose: BusinessPurpose.advanceCollection,
    )) {
      return _rewriteAccountManagedAdvanceCollection(
        group: _currentGroup(rootGroup),
        instruction: instruction,
      );
    }
    final target = _loadAdvanceChild(
      rootGroup: rootGroup,
      transactionId: instruction.transactionId,
      purpose: BusinessPurpose.advanceCollection,
      targetViolation:
          LedgerViolationReason.advanceCollectionTransactionRequired,
      requireOpenGroup: false,
    );
    final group = target.group;
    final currentReceipt = target.child;
    final remaining = group.advanceOutstanding() + currentReceipt.primaryAmount;
    final amount = instruction.amount ?? currentReceipt.primaryAmount;
    if (group.advanceSettled && amount != currentReceipt.primaryAmount) {
      LedgerViolationReason.advanceAlreadyClosed.throwException();
    }
    if (amount.minorUnits > remaining.minorUnits) {
      LedgerViolationReason.advanceCollectionExceedsOutstanding
          .throwException();
    }
    final receivableAccountId = _itemizedAdvanceReceivableAccountId(
      group: group,
      requestedAccountId: instruction.receivableAccountId,
      unresolvedViolation:
          LedgerViolationReason.advanceCollectionAccountsUnresolved,
    );
    final settlements = patchAllocations(
      current: currentReceipt.accountAllocationsOf(
        TransactionRole.settlementIn,
      ),
      total: amount,
      explicit: instruction.settlementAllocations,
    );
    final roleViolation = await _accountRolePolicy.validate(
      AccountRoleContext.advanceCollection(
        receivableAccountId: receivableAccountId,
        receiveAccountIds: settlements.map(
          (allocation) => allocation.accountId,
        ),
      ),
    );
    if (roleViolation != null) roleViolation.throwException();
    final candidate = _postingEngine.createAdvanceCollection(
      instruction: AdvanceCollectionInstruction(
        advanceTransactionId: group.parentTransaction.id,
        amount: amount,
        receivableAccountId: receivableAccountId,
        settlementAllocations: settlements,
        occurredAt: currentReceipt.occurredAt,
        counterpartyId: currentReceipt.counterpartyId,
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
      counterpartyId: instruction.counterpartyId,
      note: instruction.note,
    );
    return _singleChildRewrite(
      group: group,
      original: currentReceipt,
      rewritten: rewritten,
    );
  }

  Future<TransactionGroupRewriteResult> rewriteAdvanceSettlement(
    EditAdvanceSettlementTransactionInstruction instruction,
  ) async {
    final rootGroup = await _loadRootGroup(instruction.transactionId);
    if (_isAccountManagedTopLevel(
      rootGroup,
      transactionId: instruction.transactionId,
      purpose: BusinessPurpose.advanceSettlement,
    )) {
      return _rewriteAccountManagedAdvanceSettlement(
        group: _currentGroup(rootGroup),
        instruction: instruction,
      );
    }
    final target = _loadAdvanceChild(
      rootGroup: rootGroup,
      transactionId: instruction.transactionId,
      purpose: BusinessPurpose.advanceSettlement,
      targetViolation:
          LedgerViolationReason.advanceSettlementTransactionRequired,
      requireOpenGroup: false,
    );
    final group = target.group;
    final currentClose = target.child;
    // 待核销与实收都来自交易组与自有分项,不从垫付结清的派生分项反算。
    final outstanding = group.advanceOutstandingExcluding(currentClose.id);
    final currentSettlements = currentClose.accountAllocationsOf(
      TransactionRole.settlementIn,
    );
    final actual =
        instruction.actualReceivedAmount ?? sumAllocations(currentSettlements);
    final receivableAccountId = _itemizedAdvanceReceivableAccountId(
      group: group,
      requestedAccountId: instruction.receivableAccountId,
      unresolvedViolation:
          LedgerViolationReason.advanceSettlementAccountsUnresolved,
    );
    final settlements = patchAllocations(
      current: currentSettlements,
      total: actual,
      explicit: instruction.settlementAllocations,
    );
    final shortfall = outstanding - actual;
    final shortfallKind =
        instruction.shortfallKind ??
        (currentClose.linesOf(TransactionRole.advanceBadDebtExpense).isNotEmpty
            ? AdvanceShortfallKind.badDebt
            : AdvanceShortfallKind.selfBorne);
    final gapExpenseAllocations =
        shortfall.minorUnits > 0 &&
            shortfallKind == AdvanceShortfallKind.selfBorne
        ? patchAllocations(
            current: currentClose.accountAllocationsOf(
              TransactionRole.advanceSelfBorne,
            ),
            total: shortfall,
            explicit: instruction.gapExpenseAllocations,
          )
        : const <AccountAmountAllocation>[];
    final gapIncomeAccountId = actual.minorUnits > outstanding.minorUnits
        ? await _systemAccountResolver.resolveAdvanceCompensationIncome()
        : null;
    final badDebtExpenseAccountId =
        shortfall.minorUnits > 0 &&
            shortfallKind == AdvanceShortfallKind.badDebt
        ? await _systemAccountResolver.resolveByKey(SystemKey.badDebtExpense)
        : null;
    final roleViolation = await _accountRolePolicy.validate(
      AccountRoleContext.advanceSettlement(
        receivableAccountId: receivableAccountId,
        receiveAccountIds: settlements.map(
          (allocation) => allocation.accountId,
        ),
        gapExpenseCategoryIds: gapExpenseAllocations.map(
          (allocation) => allocation.accountId,
        ),
        receivesCash: actual.minorUnits > 0,
      ),
    );
    if (roleViolation != null) roleViolation.throwException();
    final candidate = _postingEngine.createAdvanceSettlement(
      instruction: AdvanceSettlementInstruction(
        advanceTransactionId: group.parentTransaction.id,
        actualReceivedAmount: actual,
        receivableAccountId: receivableAccountId,
        settlementAllocations: settlements,
        gapExpenseAllocations: gapExpenseAllocations,
        shortfallKind: shortfallKind,
        occurredAt: currentClose.occurredAt,
        counterpartyId: currentClose.counterpartyId,
        note: currentClose.note,
      ),
      advance: group.parentTransaction,
      outstanding: outstanding,
      gapIncomeAccountId: gapIncomeAccountId,
      badDebtExpenseAccountId: badDebtExpenseAccountId,
    );
    final rewritten = _preserveIdentity(
      original: currentClose,
      candidate: candidate,
    );
    rewritten.updateBasicInfo(
      occurredAt: instruction.occurredAt,
      counterpartyId: instruction.counterpartyId,
      note: instruction.note,
    );
    return _singleChildRewrite(
      group: group,
      original: currentClose,
      rewritten: rewritten,
    );
  }

  Future<TransactionGroupRewriteResult>
  _rewriteAccountManagedAdvanceCollection({
    required TransactionGroup group,
    required EditAdvanceCollectionTransactionInstruction instruction,
  }) async {
    final currentReceipt = group.parentTransaction;
    final amount = instruction.amount ?? currentReceipt.primaryAmount;
    final receivableAccountId =
        instruction.receivableAccountId ??
        currentReceipt.accountOf(TransactionRole.receivable);
    if (receivableAccountId == null) {
      LedgerViolationReason.advanceCollectionAccountsUnresolved
          .throwException();
    }
    final settlements = patchAllocations(
      current: currentReceipt.accountAllocationsOf(
        TransactionRole.settlementIn,
      ),
      total: amount,
      explicit: instruction.settlementAllocations,
    );
    final roleViolation = await _accountRolePolicy.validate(
      AccountRoleContext.advanceCollection(
        receivableAccountId: receivableAccountId,
        receiveAccountIds: settlements.map(
          (allocation) => allocation.accountId,
        ),
      ),
    );
    if (roleViolation != null) roleViolation.throwException();
    final ownership = _accountManagedOwnership(
      current: currentReceipt,
      requested: instruction.ownership,
    );
    final candidate = _postingEngine.createAdvanceCollection(
      instruction: AdvanceCollectionInstruction.account(
        amount: amount,
        receivableAccountId: receivableAccountId,
        settlementAllocations: settlements,
        ownership: ownership,
        occurredAt: currentReceipt.occurredAt,
        counterpartyId: currentReceipt.counterpartyId,
        note: currentReceipt.note,
        isExcludedFromStats: currentReceipt.isExcludedFromStats,
        isExcludedFromBudget: currentReceipt.isExcludedFromBudget,
      ),
    );
    final rewritten = _preserveIdentity(
      original: currentReceipt,
      candidate: candidate,
    );
    rewritten.updateOwnership(ownership);
    rewritten.updateBasicInfo(
      occurredAt: instruction.occurredAt,
      counterpartyId: instruction.counterpartyId,
      note: instruction.note,
    );
    return _singleTopLevelRewrite(
      group: group,
      original: currentReceipt,
      rewritten: rewritten,
    );
  }

  Future<TransactionGroupRewriteResult>
  _rewriteAccountManagedAdvanceSettlement({
    required TransactionGroup group,
    required EditAdvanceSettlementTransactionInstruction instruction,
  }) async {
    final currentClose = group.parentTransaction;
    final currentSettlements = currentClose.accountAllocationsOf(
      TransactionRole.settlementIn,
    );
    final actual =
        instruction.actualReceivedAmount ?? sumAllocations(currentSettlements);
    final receivableAccountId =
        instruction.receivableAccountId ??
        currentClose.accountOf(TransactionRole.receivable);
    if (receivableAccountId == null) {
      LedgerViolationReason.advanceSettlementAccountsUnresolved
          .throwException();
    }
    final settlements = patchAllocations(
      current: currentSettlements,
      total: actual,
      explicit: instruction.settlementAllocations,
    );
    final gapExpenseAllocations =
        instruction.gapExpenseAllocations ??
        currentClose.accountAllocationsOf(TransactionRole.advanceSelfBorne);
    final roleViolation = await _accountRolePolicy.validate(
      AccountRoleContext.advanceSettlement(
        receivableAccountId: receivableAccountId,
        receiveAccountIds: settlements.map(
          (allocation) => allocation.accountId,
        ),
        gapExpenseCategoryIds: gapExpenseAllocations.map(
          (allocation) => allocation.accountId,
        ),
        receivesCash: actual.minorUnits > 0,
      ),
    );
    if (roleViolation != null) roleViolation.throwException();
    final ownership = _accountManagedOwnership(
      current: currentClose,
      requested: instruction.ownership,
    );
    final candidate = _postingEngine.createAdvanceSettlement(
      instruction: AdvanceSettlementInstruction.account(
        actualReceivedAmount: actual,
        receivableAccountId: receivableAccountId,
        settlementAllocations: settlements,
        gapExpenseAllocations: gapExpenseAllocations,
        shortfallKind:
            instruction.shortfallKind ?? AdvanceShortfallKind.selfBorne,
        ownership: ownership,
        occurredAt: currentClose.occurredAt,
        counterpartyId: currentClose.counterpartyId,
        note: currentClose.note,
        isExcludedFromStats: currentClose.isExcludedFromStats,
        isExcludedFromBudget: currentClose.isExcludedFromBudget,
      ),
      outstanding: Money.zero(),
      gapIncomeAccountId: null,
    );
    final rewritten = _preserveIdentity(
      original: currentClose,
      candidate: candidate,
    );
    rewritten.updateOwnership(ownership);
    rewritten.updateBasicInfo(
      occurredAt: instruction.occurredAt,
      counterpartyId: instruction.counterpartyId,
      note: instruction.note,
    );
    return _singleTopLevelRewrite(
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
        group.advanceSettled &&
        target.businessPurpose != BusinessPurpose.advanceSettlement) {
      LedgerViolationReason.advanceAlreadyClosed.throwException();
    }
    final deleted = target.id == group.parentTransaction.id
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

  Future<TransactionGroup> _loadRootGroup(String transactionId) async {
    final group = await _transactionGroupRepository.findByTransactionId(
      transactionId,
    );
    if (group == null) {
      LedgerViolationReason.transactionNotFound.throwException();
    }
    return group;
  }

  bool _isAccountManagedTopLevel(
    TransactionGroup group, {
    required String transactionId,
    required BusinessPurpose purpose,
  }) {
    // 账户垫付的到账与结清是 ownerless 顶层交易。
    final transaction = group.parentTransaction;
    return transaction.id == transactionId &&
        transaction.businessPurpose == purpose &&
        group.childTransactions.isEmpty;
  }

  ({TransactionGroup group, Transaction child}) _loadAdvanceChild({
    required TransactionGroup rootGroup,
    required String transactionId,
    required BusinessPurpose purpose,
    required LedgerViolationReason targetViolation,
    required bool requireOpenGroup,
  }) {
    final group = _currentGroup(rootGroup);
    final child = group.findTransaction(transactionId);
    if (child == null ||
        child.id == group.parentTransaction.id ||
        child.businessPurpose != purpose) {
      targetViolation.throwException();
    }
    if (requireOpenGroup && group.advanceSettled) {
      LedgerViolationReason.advanceAlreadyClosed.throwException();
    }
    final advanceViolation = _validateAdvance(rootGroup);
    if (advanceViolation != null) advanceViolation.throwException();
    return (group: group, child: child);
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
    final accountingExpressionChanged = !original.hasSameAccountingExpressionAs(
      rewritten,
    );
    final plan = TransactionGroupRewritePlan(
      rewrites: accountingExpressionChanged
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
    final changedAccounts = accountingExpressionChanged
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

  Future<TransactionGroupRewriteResult> _singleTopLevelRewrite({
    required TransactionGroup group,
    required Transaction original,
    required Transaction rewritten,
  }) async {
    final accountingExpressionChanged = !original.hasSameAccountingExpressionAs(
      rewritten,
    );
    final plan = TransactionGroupRewritePlan(
      rewrites: accountingExpressionChanged
          ? [TransactionRewrite(before: original, after: rewritten)]
          : const [],
      rowUpdates: accountingExpressionChanged ? const [] : [rewritten],
      currentGroup: TransactionGroup(
        parentTransaction: rewritten,
        childTransactions: group.childTransactions,
      ),
    );
    final changedAccounts = accountingExpressionChanged
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

  LedgerViolationReason? _validateAdvance(TransactionGroup group) {
    final advance = group.parentTransaction;
    if (advance.businessPurpose != BusinessPurpose.advance) {
      return LedgerViolationReason.advanceParentNotAdvance;
    }
    return null;
  }

  String _itemizedAdvanceReceivableAccountId({
    required TransactionGroup group,
    required String? requestedAccountId,
    required LedgerViolationReason unresolvedViolation,
  }) {
    final parentReceivableAccountId = group.parentTransaction.accountOf(
      TransactionRole.receivable,
    );
    if (parentReceivableAccountId == null) {
      unresolvedViolation.throwException();
    }
    if (requestedAccountId != null &&
        requestedAccountId != parentReceivableAccountId) {
      LedgerViolationReason.advanceReceivableAccountMismatch.throwException();
    }
    return parentReceivableAccountId;
  }

  TransactionOwnership? _accountManagedOwnership({
    required Transaction current,
    required TransactionOwnership? requested,
  }) {
    return requested ?? current.ownership;
  }
}
