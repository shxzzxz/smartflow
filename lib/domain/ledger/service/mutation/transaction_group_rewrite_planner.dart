import '../../entity/transaction.dart';
import '../../entity/transaction_group.dart';
import '../../port/system_account_resolver.dart';
import '../../valobj/ledger_enum.dart';
import '../../valobj/account_amount_allocation.dart';
import '../../valobj/ledger_violation_reason.dart';
import '../../valobj/posting_instruction.dart';
import '../posting/posting_engine.dart';
import '../posting/posting_instruction_resolver.dart';
import 'transaction_group_rewrite_plan.dart';

class TransactionGroupRewritePlanner {
  const TransactionGroupRewritePlanner({
    required PostingEngine postingEngine,
    required PostingInstructionResolver postingInstructionResolver,
    required SystemAccountResolver systemAccountResolver,
  }) : _postingEngine = postingEngine,
       _postingInstructionResolver = postingInstructionResolver,
       _systemAccountResolver = systemAccountResolver;

  final PostingEngine _postingEngine;
  final PostingInstructionResolver _postingInstructionResolver;
  final SystemAccountResolver _systemAccountResolver;

  Future<TransactionGroupRewritePlan> planParentRewrite({
    required TransactionGroup currentGroup,
    required Transaction candidateParent,
  }) async {
    final currentParent = currentGroup.parentTransaction;
    _ensurePurposeChangeSupported(
      current: currentParent.businessPurpose,
      target: candidateParent.businessPurpose,
    );
    if (currentParent.businessPurpose == BusinessPurpose.reimbursementAdvance &&
        candidateParent.businessPurpose == BusinessPurpose.dailyExpense &&
        currentGroup.childTransactions.any(
          (child) =>
              child.businessPurpose == BusinessPurpose.reimbursementReceipt ||
              child.businessPurpose == BusinessPurpose.reimbursementClose,
        )) {
      LedgerViolationReason.transactionGroupHasIncompatibleChildren
          .throwException();
    }
    if (currentGroup.reimbursementClosed &&
        currentParent.primaryAmount != candidateParent.primaryAmount) {
      LedgerViolationReason.reimbursementAlreadyClosed.throwException();
    }

    final rewrittenParent = candidateParent.copyWith(
      id: currentParent.id,
      postedAt: currentParent.postedAt,
      sourceKind: currentParent.sourceKind,
      ownership: currentParent.ownership,
    );
    if (!currentGroup.reimbursementClosed) {
      final refunded = currentGroup.refundedTotal();
      if (rewrittenParent.businessPurpose ==
          BusinessPurpose.reimbursementAdvance) {
        final recovered = refunded + currentGroup.reimbursementReceivedTotal();
        if (recovered.minorUnits > rewrittenParent.primaryAmount.minorUnits) {
          LedgerViolationReason.reimbursementRecoveryExceedsAdvance
              .throwException();
        }
      } else if (refunded.minorUnits >
          rewrittenParent.primaryAmount.minorUnits) {
        LedgerViolationReason.refundExceedsRemaining.throwException();
      }
    }

    final rewrittenChildren = <Transaction>[];
    final rewrites = <TransactionRewrite>[];
    final rowUpdates = <Transaction>[];
    if (currentParent.hasSameAccountingExpressionAs(rewrittenParent)) {
      rowUpdates.add(rewrittenParent);
    } else {
      rewrites.add(
        TransactionRewrite(before: currentParent, after: rewrittenParent),
      );
    }
    for (final child in currentGroup.childTransactions) {
      final rewritten = await _rewriteChild(
        child: child,
        currentGroup: currentGroup,
        parent: rewrittenParent,
      );
      rewrittenChildren.add(rewritten);
      if (!child.hasSameAccountingExpressionAs(rewritten)) {
        rewrites.add(TransactionRewrite(before: child, after: rewritten));
      } else if (!identical(child, rewritten) &&
          (child.isExcludedFromStats != rewritten.isExcludedFromStats ||
              child.isExcludedFromBudget != rewritten.isExcludedFromBudget)) {
        rowUpdates.add(rewritten);
      }
    }

    final rewrittenGroup = TransactionGroup(
      parentTransaction: rewrittenParent,
      childTransactions: rewrittenChildren,
    );
    _validateCategoryAllocations(rewrittenGroup);
    return TransactionGroupRewritePlan(
      rewrites: rewrites,
      rowUpdates: rowUpdates,
      currentGroup: rewrittenGroup,
    );
  }

  Future<Transaction> _rewriteChild({
    required Transaction child,
    required TransactionGroup currentGroup,
    required Transaction parent,
  }) async {
    switch (child.businessPurpose) {
      case BusinessPurpose.reimbursementReceipt:
        return _rebuildReceipt(child: child, parent: parent);
      case BusinessPurpose.reimbursementClose:
        return _rebuildClose(
          child: child,
          currentGroup: currentGroup,
          parent: parent,
        );
      case BusinessPurpose.refund:
        return _rebuildRefund(
          child: child,
          currentGroup: currentGroup,
          parent: parent,
        );
      default:
        return child.copyWith(
          isExcludedFromStats: parent.isExcludedFromStats,
          isExcludedFromBudget: parent.isExcludedFromBudget,
        );
    }
  }

  Transaction _rebuildRefund({
    required Transaction child,
    required TransactionGroup currentGroup,
    required Transaction parent,
  }) {
    final instruction = _postingInstructionResolver.resolveRefund(child);
    final categories = _rebaseSingleCategoryAllocations(
      currentParent: currentGroup.parentTransaction,
      nextParent: parent,
      allocations: instruction.categoryAllocations,
    );
    final candidate = _postingEngine.createRefund(
      instruction: RefundInstruction(
        parentTransactionId: parent.id,
        amount: instruction.amount,
        categoryAllocations: categories,
        settlementAllocations: instruction.settlementAllocations,
        occurredAt: instruction.occurredAt,
        postedAt: instruction.postedAt,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
      ),
      parent: parent,
    );
    return _preserveIdentity(original: child, candidate: candidate);
  }

  /// 报销到账跟随父交易的应收科目重建:重算分项后重新过账,而不是改写既有分录。
  Transaction _rebuildReceipt({
    required Transaction child,
    required Transaction parent,
  }) {
    final parentInstruction = _postingInstructionResolver.resolve(parent);
    if (parentInstruction is! ReimbursementAdvanceInstruction) return child;
    final settlements = _allocationsOf(child, TransactionRole.settlementIn);
    if (settlements.isEmpty) {
      LedgerViolationReason.reimbursementReceiptAccountsUnresolved
          .throwException();
    }
    final candidate = _postingEngine.createReimbursementReceipt(
      instruction: ReimbursementReceiptInstruction(
        advanceTransactionId: parent.id,
        amount: child.primaryAmount,
        receivableAccountId: parentInstruction.receivableAccountId,
        settlementAllocations: settlements,
        occurredAt: child.occurredAt,
        postedAt: child.postedAt,
        counterpartyName: child.counterpartyName,
        note: child.note,
      ),
      advance: parent,
    );
    return _preserveIdentity(original: child, candidate: candidate);
  }

  Future<Transaction> _rebuildClose({
    required Transaction child,
    required TransactionGroup currentGroup,
    required Transaction parent,
  }) async {
    final parentInstruction = _postingInstructionResolver.resolve(parent);
    if (parentInstruction is! ReimbursementAdvanceInstruction) return child;
    final settlements = _allocationsOf(child, TransactionRole.settlementIn);
    if (settlements.isEmpty) {
      LedgerViolationReason.reimbursementCloseAccountsUnresolved
          .throwException();
    }
    // 待核销由交易组推导,不读结束报销自己的派生分项。
    final outstanding = TransactionGroup(
      parentTransaction: parent,
      childTransactions: currentGroup.childTransactions,
    ).reimbursementOutstandingExcluding(child.id);
    final actual = sumAllocations(settlements);
    final gapExpenseAllocations = _rebaseSingleCategoryAllocations(
      currentParent: currentGroup.parentTransaction,
      nextParent: parent,
      allocations: _allocationsOf(
        child,
        TransactionRole.reimbursementGapExpense,
      ),
    );
    final candidate = _postingEngine.createReimbursementClose(
      instruction: ReimbursementCloseInstruction(
        advanceTransactionId: parent.id,
        actualReceivedAmount: actual,
        receivableAccountId: parentInstruction.receivableAccountId,
        settlementAllocations: settlements,
        gapExpenseAllocations: gapExpenseAllocations,
        occurredAt: child.occurredAt,
        postedAt: child.postedAt,
        counterpartyName: child.counterpartyName,
        note: child.note,
      ),
      advance: parent,
      outstanding: outstanding,
      gapIncomeAccountId: actual.minorUnits > outstanding.minorUnits
          ? await _systemAccountResolver.resolveReimbursementGapIncome()
          : null,
    );
    return _preserveIdentity(original: child, candidate: candidate);
  }

  void _validateCategoryAllocations(TransactionGroup group) {
    for (final child in group.childTransactions) {
      if (child.businessPurpose == BusinessPurpose.refund &&
          !group.allocationsFitRefundableCategories(
            group.refundCategoryAllocations(child),
            excludingTransactionId: child.id,
          )) {
        LedgerViolationReason.allocationExceedsAvailable.throwException();
      }
      if (child.businessPurpose == BusinessPurpose.reimbursementClose) {
        final gaps = _allocationsOf(
          child,
          TransactionRole.reimbursementGapExpense,
        );
        if (!group.allocationsFitRefundableCategories(gaps)) {
          LedgerViolationReason.allocationExceedsAvailable.throwException();
        }
      }
    }
  }

  List<AccountAmountAllocation> _allocationsOf(
    Transaction transaction,
    TransactionRole role,
  ) {
    return [
      for (final line in transaction.linesOf(role))
        AccountAmountAllocation(
          accountId: line.accountId!,
          amount: line.amount,
        ),
    ];
  }

  List<AccountAmountAllocation> _rebaseSingleCategoryAllocations({
    required Transaction currentParent,
    required Transaction nextParent,
    required List<AccountAmountAllocation> allocations,
  }) {
    final currentCategories = TransactionGroup(
      parentTransaction: currentParent,
      childTransactions: const [],
    ).categoryAllocations;
    final nextCategories = TransactionGroup(
      parentTransaction: nextParent,
      childTransactions: const [],
    ).categoryAllocations;
    if (currentCategories.length != 1 || nextCategories.length != 1) {
      final currentById = {
        for (final allocation in currentCategories)
          allocation.accountId: allocation.amount.minorUnits,
      };
      final nextById = {
        for (final allocation in nextCategories)
          allocation.accountId: allocation.amount.minorUnits,
      };
      final removed = currentById.keys
          .where((accountId) => !nextById.containsKey(accountId))
          .toList();
      final increased = nextById.keys
          .where(
            (accountId) => nextById[accountId]! > (currentById[accountId] ?? 0),
          )
          .toList();
      if (removed.length != 1 || increased.length != 1) return allocations;
      return replaceAllocationAccount(
        allocations: allocations,
        sourceAccountId: removed.single,
        targetAccountId: increased.single,
      );
    }
    final currentId = currentCategories.single.accountId;
    final nextId = nextCategories.single.accountId;
    if (currentId == nextId) return allocations;
    return [
      for (final allocation in allocations)
        allocation.accountId == currentId
            ? allocation.copyWith(accountId: nextId)
            : allocation,
    ];
  }

  Transaction _preserveIdentity({
    required Transaction original,
    required Transaction candidate,
  }) {
    return candidate.copyWith(
      id: original.id,
      postedAt: original.postedAt,
      sourceKind: original.sourceKind,
      ownership: original.ownership,
    );
  }

  void _ensurePurposeChangeSupported({
    required BusinessPurpose current,
    required BusinessPurpose target,
  }) {
    if (current == target) return;
    final supported =
        (current == BusinessPurpose.dailyExpense &&
            target == BusinessPurpose.reimbursementAdvance) ||
        (current == BusinessPurpose.reimbursementAdvance &&
            target == BusinessPurpose.dailyExpense);
    if (!supported) {
      LedgerViolationReason.unsupportedEditSource.throwException();
    }
  }
}
