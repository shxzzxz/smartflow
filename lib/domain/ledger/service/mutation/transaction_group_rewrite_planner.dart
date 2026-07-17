import '../../entity/transaction.dart';
import '../../entity/transaction_group.dart';
import '../../entity/entry.dart';
import '../../valobj/ledger_enum.dart';
import '../../valobj/ledger_violation_reason.dart';
import '../../valobj/posting_instruction.dart';
import '../posting/posting_engine.dart';
import '../posting/posting_instruction_resolver.dart';
import 'transaction_group_rewrite_plan.dart';

class TransactionGroupRewritePlanner {
  const TransactionGroupRewritePlanner({
    required PostingEngine postingEngine,
    required PostingInstructionResolver postingInstructionResolver,
  }) : _postingEngine = postingEngine,
       _postingInstructionResolver = postingInstructionResolver;

  final PostingEngine _postingEngine;
  final PostingInstructionResolver _postingInstructionResolver;

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
    if (currentGroup.refundedTotal().minorUnits >
        rewrittenParent.primaryAmount.minorUnits) {
      LedgerViolationReason.refundExceedsRemaining.throwException();
    }
    if (rewrittenParent.businessPurpose ==
            BusinessPurpose.reimbursementAdvance &&
        currentGroup.reimbursementReceivedTotal().minorUnits >
            rewrittenParent.primaryAmount.minorUnits) {
      LedgerViolationReason.reimbursementReceiptExceedsOutstanding
          .throwException();
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
      final rewritten = _rewriteChild(
        child: child,
        currentParent: currentParent,
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

    return TransactionGroupRewritePlan(
      rewrites: rewrites,
      rowUpdates: rowUpdates,
      currentGroup: TransactionGroup(
        parentTransaction: rewrittenParent,
        childTransactions: rewrittenChildren,
      ),
    );
  }

  Transaction _rewriteChild({
    required Transaction child,
    required Transaction currentParent,
    required Transaction parent,
  }) {
    if (child.businessPurpose == BusinessPurpose.reimbursementReceipt ||
        child.businessPurpose == BusinessPurpose.reimbursementClose) {
      return _rebaseReimbursementChild(
        child: child,
        currentParent: currentParent,
        parent: parent,
      );
    }
    if (child.businessPurpose != BusinessPurpose.refund) {
      return child.copyWith(
        isExcludedFromStats: parent.isExcludedFromStats,
        isExcludedFromBudget: parent.isExcludedFromBudget,
      );
    }
    final parentInstruction = _postingInstructionResolver.resolve(parent);
    final offsetAccountId = resolveRefundOffsetAccountId(parentInstruction);
    if (offsetAccountId == null) {
      LedgerViolationReason.refundParentNotSupported.throwException();
    }
    final instruction = _postingInstructionResolver.resolveRefund(child);
    final candidate = _postingEngine.createRefund(
      instruction: RefundInstruction(
        parentTransactionId: parent.id,
        amount: instruction.amount,
        refundToAccountId: instruction.refundToAccountId,
        occurredAt: instruction.occurredAt,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
      ),
      parent: parent,
      refundOffsetAccountId: offsetAccountId,
    );
    return candidate.copyWith(
      id: child.id,
      parentTransactionId: parent.id,
      sourceKind: child.sourceKind,
      ownership: child.ownership,
    );
  }

  Transaction _rebaseReimbursementChild({
    required Transaction child,
    required Transaction currentParent,
    required Transaction parent,
  }) {
    final currentParentInstruction = _postingInstructionResolver.resolve(
      currentParent,
    );
    final parentInstruction = _postingInstructionResolver.resolve(parent);
    if (currentParentInstruction is! ReimbursementAdvanceInstruction ||
        parentInstruction is! ReimbursementAdvanceInstruction) {
      return child;
    }
    final currentReceivableAccountId =
        currentParentInstruction.receivableAccountId;
    return child.copyWith(
      parentTransactionId: parent.id,
      isExcludedFromStats: parent.isExcludedFromStats,
      isExcludedFromBudget: parent.isExcludedFromBudget,
      entries: [
        for (final entry in child.entries)
          Entry(
            id: entry.id,
            transactionId: child.id,
            accountId: _rebaseReimbursementAccount(
              accountId: entry.accountId,
              childPurpose: child.businessPurpose,
              currentParent: currentParent,
              parent: parent,
              currentReceivableAccountId: currentReceivableAccountId,
              receivableAccountId: parentInstruction.receivableAccountId,
            ),
            direction: entry.direction,
            amount: entry.amount,
          ),
      ],
    );
  }

  String _rebaseReimbursementAccount({
    required String accountId,
    required BusinessPurpose childPurpose,
    required Transaction currentParent,
    required Transaction parent,
    required String currentReceivableAccountId,
    required String receivableAccountId,
  }) {
    if (accountId == currentReceivableAccountId) return receivableAccountId;
    if (childPurpose == BusinessPurpose.reimbursementClose &&
        currentParent.reimbursementExpenseAccountId != null &&
        accountId == currentParent.reimbursementExpenseAccountId) {
      return parent.reimbursementExpenseAccountId!;
    }
    return accountId;
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
