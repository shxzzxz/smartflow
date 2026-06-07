import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_rule.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/posting_instruction.dart';

import '../../../../helper/sequential_id_generator.dart';

void main() {
  group('PostingEngine', () {
    test('creates balanced expense transaction', () {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'tx'),
      );

      final transaction = engine.createExpense(
        ExpenseInstruction(
          amount: Money.parse('12.30'),
          paidFromAccountId: 'cash',
          expenseAccountId: 'food',
          occurredAt: DateTime(2026, 5, 1),
        ),
      );

      expect(transaction.businessPurpose, BusinessPurpose.dailyExpense);
      expect(transaction.rootTransactionId, transaction.id);
      expect(
        transaction.details.single.type,
        TransactionDetailType.primaryExpense,
      );
      expect(entriesAreBalanced(transaction.entries), isTrue);
      expect(
        transaction.entries.map((entry) => (entry.accountId, entry.direction)),
        containsAll([
          ('food', EntryDirection.debit),
          ('cash', EntryDirection.credit),
        ]),
      );
    });

    test('creates refund inheriting parent reporting flags', () {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'tx'),
      );
      final parent = engine.createExpense(
        ExpenseInstruction(
          amount: Money.parse('20.00'),
          paidFromAccountId: 'cash',
          expenseAccountId: 'food',
          occurredAt: DateTime(2026, 5, 1),
          isExcludedFromStats: true,
          isExcludedFromBudget: true,
        ),
      );

      final refund = engine.createRefund(
        instruction: RefundInstruction(
          parentTransactionId: parent.id,
          amount: Money.parse('8.00'),
          refundToAccountId: 'cash',
          occurredAt: DateTime(2026, 5, 2),
        ),
        parent: parent,
        refundOffsetAccountId: 'food',
      );

      expect(refund.rootTransactionId, parent.rootTransactionId);
      expect(refund.parentTransactionId, parent.id);
      expect(refund.isExcludedFromStats, isTrue);
      expect(refund.isExcludedFromBudget, isTrue);
      expect(entriesAreBalanced(refund.entries), isTrue);
    });

    test('creates replacement chain original to reversal to correction', () {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'tx'),
      );
      final original = engine.createExpense(
        ExpenseInstruction(
          amount: Money.parse('10.00'),
          paidFromAccountId: 'cash',
          expenseAccountId: 'food',
          occurredAt: DateTime(2026, 5, 1),
        ),
      );
      final candidate = engine.createExpense(
        ExpenseInstruction(
          amount: Money.parse('11.00'),
          paidFromAccountId: 'card',
          expenseAccountId: 'food',
          occurredAt: DateTime(2026, 5, 1),
        ),
      );

      final replacement = engine.createReplacement(
        original: original,
        replacement: candidate,
        reason: MutationReason.correction,
      );

      expect(
        replacement.replacedTransaction.businessState,
        BusinessState.replaced,
      );
      expect(
        replacement.reversalTransaction.businessState,
        BusinessState.compensation,
      );
      expect(
        replacement.reversalTransaction.mutationPreviousTransactionId,
        original.id,
      );
      expect(
        replacement.correctionTransaction.businessState,
        BusinessState.current,
      );
      expect(
        replacement.correctionTransaction.mutationPreviousTransactionId,
        replacement.reversalTransaction.id,
      );
      expect(
        replacement.correctionTransaction.rootTransactionId,
        original.rootTransactionId,
      );
    });
  });
}
