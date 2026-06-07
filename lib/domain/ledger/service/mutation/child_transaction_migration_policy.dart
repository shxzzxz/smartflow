import '../../entity/root_transaction_group.dart';
import '../../entity/transaction.dart';
import '../../valobj/ledger_enum.dart';
import '../../valobj/ledger_violation_reason.dart';
import '../../valobj/posting_instruction.dart';
import '../../valobj/posting_result.dart';
import '../posting/posting_engine.dart';
import '../posting/posting_instruction_resolver.dart';

abstract interface class ChildTransactionMigrationPolicy {
  LedgerViolationReason? validateConvertible({
    required RootTransactionGroup oldGroup,
    required BusinessPurpose newParentPurpose,
    required Transaction newParent,
  });

  Future<List<ChildTransactionMigration>> migrateChildren({
    required RootTransactionGroup oldGroup,
    required Transaction newParent,
  });
}

class RefundOnlyChildMigrationPolicy
    implements ChildTransactionMigrationPolicy {
  const RefundOnlyChildMigrationPolicy({
    required PostingEngine postingEngine,
    required PostingInstructionResolver postingInstructionResolver,
  }) : _postingEngine = postingEngine,
       _postingInstructionResolver = postingInstructionResolver;

  final PostingEngine _postingEngine;
  final PostingInstructionResolver _postingInstructionResolver;

  @override
  LedgerViolationReason? validateConvertible({
    required RootTransactionGroup oldGroup,
    required BusinessPurpose newParentPurpose,
    required Transaction newParent,
  }) {
    final refundSupported =
        newParentPurpose == BusinessPurpose.dailyExpense ||
        newParentPurpose == BusinessPurpose.reimbursementAdvance;
    if (!refundSupported && oldGroup.childTransactions.isNotEmpty) {
      return LedgerViolationReason.transactionGroupChildMigrationNotSupported;
    }
    for (final child in oldGroup.childTransactions) {
      if (child.businessPurpose != BusinessPurpose.refund) {
        return LedgerViolationReason.transactionGroupHasUnconvertibleChildren;
      }
    }
    if (oldGroup.refundedTotal().minorUnits >
        newParent.primaryAmount.minorUnits) {
      return LedgerViolationReason.refundExceedsRemaining;
    }
    return null;
  }

  @override
  Future<List<ChildTransactionMigration>> migrateChildren({
    required RootTransactionGroup oldGroup,
    required Transaction newParent,
  }) async {
    final parentInstruction = _postingInstructionResolver.resolve(newParent);
    final refundOffsetAccountId = resolveRefundOffsetAccountId(
      parentInstruction,
    );
    if (refundOffsetAccountId == null) {
      LedgerViolationReason.refundParentNotSupported.throwException(
        message: 'This parent transaction does not support refunds.',
      );
    }

    final migrations = <ChildTransactionMigration>[];
    for (final oldChild in oldGroup.childTransactions) {
      final currentRefund = _postingInstructionResolver.resolveRefund(oldChild);
      final candidate = _postingEngine.createRefund(
        instruction: RefundInstruction(
          parentTransactionId: newParent.id,
          amount: currentRefund.amount,
          refundToAccountId: currentRefund.refundToAccountId,
          occurredAt: currentRefund.occurredAt,
          counterpartyName: currentRefund.counterpartyName,
          note: currentRefund.note,
        ),
        parent: newParent,
        refundOffsetAccountId: refundOffsetAccountId,
      );
      migrations.add(
        ChildTransactionMigration(
          originalChild: oldChild,
          replacementCandidate: candidate,
        ),
      );
    }
    return migrations;
  }
}
