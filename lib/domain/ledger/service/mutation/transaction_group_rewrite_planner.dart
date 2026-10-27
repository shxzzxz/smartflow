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
    Map<String, List<AccountAmountAllocation>> refundSelfBorneAllocations =
        const {},
  }) async {
    final currentParent = currentGroup.parentTransaction;
    _ensurePurposeChangeSupported(
      currentParent: currentParent,
      candidateParent: candidateParent,
    );
    if (currentParent.businessPurpose == BusinessPurpose.advance &&
        candidateParent.businessPurpose == BusinessPurpose.dailyExpense &&
        currentGroup.childTransactions.any(
          (child) =>
              child.businessPurpose == BusinessPurpose.advanceCollection ||
              child.businessPurpose == BusinessPurpose.advanceSettlement,
        )) {
      LedgerViolationReason.transactionGroupHasIncompatibleChildren
          .throwException();
    }
    if (currentGroup.advanceSettled &&
        currentParent.primaryAmount != candidateParent.primaryAmount) {
      LedgerViolationReason.advanceAlreadyClosed.throwException();
    }

    final rewrittenParent = candidateParent.copyWith(
      id: currentParent.id,
      postedAt: currentParent.postedAt,
      sourceKind: currentParent.sourceKind,
      clearOwnership:
          currentParent.businessPurpose == BusinessPurpose.advance &&
          candidateParent.businessPurpose != BusinessPurpose.advance,
    );
    if (!currentGroup.advanceSettled) {
      final refunded = currentGroup.refundedTotal();
      if (rewrittenParent.businessPurpose == BusinessPurpose.advance) {
        final recovered =
            currentGroup.advanceRefundedTotal() +
            currentGroup.advanceCollectedTotal();
        final nextAdvanceAmount =
            rewrittenParent.amountOf(TransactionRole.receivable) ??
            rewrittenParent.primaryAmount;
        if (recovered.minorUnits > nextAdvanceAmount.minorUnits) {
          LedgerViolationReason.advanceRecoveryExceedsAdvance.throwException();
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
        refundSelfBorneAllocations: refundSelfBorneAllocations,
      );
      rewrittenChildren.add(rewritten);
      if (!child.hasSameAccountingExpressionAs(rewritten)) {
        rewrites.add(TransactionRewrite(before: child, after: rewritten));
      } else if (!identical(child, rewritten) &&
          (child.ownership != rewritten.ownership ||
              child.isExcludedFromStats != rewritten.isExcludedFromStats ||
              child.isExcludedFromBudget != rewritten.isExcludedFromBudget)) {
        rowUpdates.add(rewritten);
      }
    }

    final rewrittenGroup = TransactionGroup(
      parentTransaction: rewrittenParent,
      childTransactions: rewrittenChildren,
    );
    _validateRefundCategoryAllocations(rewrittenGroup);
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
    required Map<String, List<AccountAmountAllocation>>
    refundSelfBorneAllocations,
  }) async {
    switch (child.businessPurpose) {
      case BusinessPurpose.advanceCollection:
        return _rebuildReceipt(child: child, parent: parent);
      case BusinessPurpose.advanceSettlement:
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
          selfBorneAllocations:
              refundSelfBorneAllocations[child.id] ?? const [],
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
    required List<AccountAmountAllocation> selfBorneAllocations,
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
        selfBorneAllocations: selfBorneAllocations.isEmpty
            ? instruction.selfBorneAllocations
            : selfBorneAllocations,
        settlementAllocations: instruction.settlementAllocations,
        occurredAt: instruction.occurredAt,
        postedAt: instruction.postedAt,
        counterpartyId: instruction.counterpartyId,
        note: instruction.note,
      ),
      parent: parent,
    );
    return _preserveIdentity(original: child, candidate: candidate);
  }

  /// 垫付到账跟随父交易的应收科目重建:重算分项后重新过账,而不是改写既有分录。
  Transaction _rebuildReceipt({
    required Transaction child,
    required Transaction parent,
  }) {
    final parentInstruction = _postingInstructionResolver.resolve(parent);
    if (parentInstruction is! AdvanceInstruction) return child;
    final settlements = child.accountAllocationsOf(
      TransactionRole.settlementIn,
    );
    if (settlements.isEmpty) {
      LedgerViolationReason.advanceCollectionAccountsUnresolved
          .throwException();
    }
    final candidate = _postingEngine.createAdvanceCollection(
      instruction: AdvanceCollectionInstruction(
        advanceTransactionId: parent.id,
        amount: child.primaryAmount,
        receivableAccountId: parentInstruction.receivableAccountId,
        settlementAllocations: settlements,
        occurredAt: child.occurredAt,
        postedAt: child.postedAt,
        counterpartyId: child.counterpartyId,
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
    if (parentInstruction is! AdvanceInstruction) return child;
    final settlements = child.accountAllocationsOf(
      TransactionRole.settlementIn,
    );
    if (settlements.isEmpty) {
      LedgerViolationReason.advanceSettlementAccountsUnresolved
          .throwException();
    }
    // 待核销由交易组推导,不读垫付结清自己的派生分项。
    final outstanding = TransactionGroup(
      parentTransaction: parent,
      childTransactions: currentGroup.childTransactions,
    ).advanceOutstandingExcluding(child.id);
    final actual = sumAllocations(settlements);
    final shortfallKind =
        child.linesOf(TransactionRole.advanceBadDebtExpense).isNotEmpty
        ? AdvanceShortfallKind.badDebt
        : AdvanceShortfallKind.selfBorne;
    final gapExpenseAllocations = shortfallKind == AdvanceShortfallKind.badDebt
        ? const <AccountAmountAllocation>[]
        : _rebaseSingleCategoryAllocations(
            currentParent: currentGroup.parentTransaction,
            nextParent: parent,
            allocations: child.accountAllocationsOf(
              TransactionRole.advanceSelfBorne,
            ),
          );
    final badDebtExpenseAccountId =
        shortfallKind == AdvanceShortfallKind.badDebt
        ? await _systemAccountResolver.resolveByKey(SystemKey.badDebtExpense)
        : null;
    final candidate = _postingEngine.createAdvanceSettlement(
      instruction: AdvanceSettlementInstruction(
        advanceTransactionId: parent.id,
        actualReceivedAmount: actual,
        receivableAccountId: parentInstruction.receivableAccountId,
        settlementAllocations: settlements,
        gapExpenseAllocations: gapExpenseAllocations,
        shortfallKind: shortfallKind,
        occurredAt: child.occurredAt,
        postedAt: child.postedAt,
        counterpartyId: child.counterpartyId,
        note: child.note,
      ),
      advance: parent,
      outstanding: outstanding,
      gapIncomeAccountId: actual.minorUnits > outstanding.minorUnits
          ? await _systemAccountResolver.resolveAdvanceCompensationIncome()
          : null,
      badDebtExpenseAccountId: badDebtExpenseAccountId,
    );
    return _preserveIdentity(original: child, candidate: candidate);
  }

  void _validateRefundCategoryAllocations(TransactionGroup group) {
    for (final child in group.childTransactions) {
      if (child.businessPurpose == BusinessPurpose.refund &&
          !group.allocationsFitRefundableCategories(
            group.refundCategoryAllocations(child),
            excludingTransactionId: child.id,
          )) {
        LedgerViolationReason.allocationExceedsAvailable.throwException();
      }
    }
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
    );
  }

  void _ensurePurposeChangeSupported({
    required Transaction currentParent,
    required Transaction candidateParent,
  }) {
    final current = currentParent.businessPurpose;
    final target = candidateParent.businessPurpose;
    if (current == target) return;
    final supported =
        (current == BusinessPurpose.dailyExpense &&
            target == BusinessPurpose.advance) ||
        (current == BusinessPurpose.advance &&
            target == BusinessPurpose.dailyExpense);
    if (!supported) {
      LedgerViolationReason.unsupportedEditSource.throwException();
    }
  }
}
