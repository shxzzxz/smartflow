import '../../../core/error/failure.dart';
import '../../../core/result/result.dart';
import '../entity/root_transaction_group.dart';
import '../entity/transaction.dart';
import '../valobj/ledger_enum.dart';
import '../valobj/posting_instruction.dart';
import '../valobj/posting_result.dart';
import 'posting_engine.dart';
import 'posting_instruction_resolver.dart';

abstract interface class ChildTransactionMigrationPolicy {
  Failure? validateConvertible({
    required RootTransactionGroup oldGroup,
    required BusinessPurpose newParentPurpose,
    required Transaction newParent,
  });

  Future<Result<List<ChildTransactionMigration>>> migrateChildren({
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
  Failure? validateConvertible({
    required RootTransactionGroup oldGroup,
    required BusinessPurpose newParentPurpose,
    required Transaction newParent,
  }) {
    final refundSupported =
        newParentPurpose == BusinessPurpose.dailyExpense ||
        newParentPurpose == BusinessPurpose.reimbursementAdvance;
    if (!refundSupported && oldGroup.childTransactions.isNotEmpty) {
      return const Failure(
        code: 'transaction_group_child_migration_not_supported',
        message: 'This transaction group cannot be migrated.',
      );
    }
    for (final child in oldGroup.childTransactions) {
      if (child.businessPurpose != BusinessPurpose.refund) {
        return const Failure(
          code: 'transaction_group_has_unconvertible_children',
          message: 'This transaction group has unsupported child records.',
        );
      }
    }
    if (oldGroup.refundedTotal().minorUnits >
        newParent.primaryAmount.minorUnits) {
      return const Failure(
        code: 'refund_exceeds_remaining',
        message: 'Existing refunds exceed the replacement amount.',
      );
    }
    return null;
  }

  @override
  Future<Result<List<ChildTransactionMigration>>> migrateChildren({
    required RootTransactionGroup oldGroup,
    required Transaction newParent,
  }) async {
    final parentInstructionResult = _postingInstructionResolver.resolve(
      newParent,
    );
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

    final migrations = <ChildTransactionMigration>[];
    for (final oldChild in oldGroup.childTransactions) {
      final currentRefundResult = _postingInstructionResolver.resolveRefund(
        oldChild,
      );
      if (currentRefundResult case FailureResult(:final failure)) {
        return Result.failure(failure);
      }
      final currentRefund = currentRefundResult.value;
      final candidateResult = _postingEngine.createRefund(
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
      if (candidateResult case FailureResult(:final failure)) {
        return Result.failure(failure);
      }
      migrations.add(
        ChildTransactionMigration(
          originalChild: oldChild,
          replacementCandidate: candidateResult.value,
        ),
      );
    }
    return Result.success(migrations);
  }
}
