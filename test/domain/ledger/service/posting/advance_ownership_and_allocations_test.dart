import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_rule.dart';
import 'package:smartflow/domain/ledger/valobj/account_amount_allocation.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/posting_instruction.dart';
import 'package:smartflow/domain/ledger/valobj/transaction_ownership.dart';

import '../../../../helper/sequential_id_generator.dart';

void main() {
  final occurredAt = DateTime(2026, 10, 22);

  test('advance keeps category totals and self-borne shares', () {
    final engine = PostingEngine(
      idGenerator: SequentialIdGenerator(prefix: 'aa'),
    );

    final advance = engine.createAdvance(
      AdvanceInstruction(
        amount: Money.parse('300.00'),
        advanceAmount: Money.parse('200.00'),
        receivableAccountId: 'receivable',
        categoryAllocations: const [
          AccountAmountAllocation(
            accountId: 'food',
            amount: Money(minorUnits: 12000),
          ),
          AccountAmountAllocation(
            accountId: 'travel',
            amount: Money(minorUnits: 18000),
          ),
        ],
        selfBorneAllocations: const [
          AccountAmountAllocation(
            accountId: 'food',
            amount: Money(minorUnits: 4000),
          ),
          AccountAmountAllocation(
            accountId: 'travel',
            amount: Money(minorUnits: 6000),
          ),
        ],
        settlementAllocations: const [
          AccountAmountAllocation(
            accountId: 'cash',
            amount: Money(minorUnits: 18000),
          ),
          AccountAmountAllocation(
            accountId: 'bank',
            amount: Money(minorUnits: 12000),
          ),
        ],
        occurredAt: occurredAt,
        ownership: const TransactionOwnership(
          ownerType: 'orchestration.advance',
          ownerId: 'case-1',
        ),
      ),
    );

    expect(advance.ownership?.ownerType, 'orchestration.advance');
    expect(advance.ownership?.ownerId, 'case-1');
    expect(
      advance
          .accountAllocationsOf(TransactionRole.advanceExpenseCategory)
          .map((allocation) => allocation.amount.minorUnits),
      [12000, 18000],
    );
    expect(
      advance
          .accountAllocationsOf(TransactionRole.advanceSelfBorne)
          .map((allocation) => allocation.amount.minorUnits),
      [4000, 6000],
    );
    expect(
      advance.entries.where((entry) => entry.accountId == 'food').single.amount,
      Money.parse('40.00'),
    );
    expect(
      advance.entries
          .where((entry) => entry.accountId == 'travel')
          .single
          .amount,
      Money.parse('60.00'),
    );
    expect(
      advance.entries
          .where((entry) => entry.accountId == 'receivable')
          .single
          .amount,
      Money.parse('200.00'),
    );
    expect(
      advance.entries
          .where(
            (entry) => entry.accountId == 'cash' || entry.accountId == 'bank',
          )
          .map((entry) => (entry.accountId, entry.amount.minorUnits)),
      containsAll([('cash', 18000), ('bank', 12000)]),
    );
    expect(entriesAreBalanced(advance.entries), isTrue);
  });

  test('advance preserves a caller-provided top-level owner', () {
    final engine = PostingEngine(
      idGenerator: SequentialIdGenerator(prefix: 'account-advance'),
    );

    final advance = engine.createAdvance(
      AdvanceInstruction(
        amount: Money.parse('300.00'),
        advanceAmount: Money.parse('300.00'),
        receivableAccountId: 'receivable',
        categoryAllocations: singleAllocation(
          accountId: 'travel',
          amount: Money.parse('300.00'),
        ),
        selfBorneAllocations: const [],
        settlementAllocations: singleAllocation(
          accountId: 'cash',
          amount: Money.parse('300.00'),
        ),
        occurredAt: occurredAt,
        ownership: const TransactionOwnership(
          ownerType: 'orchestration.advance',
          ownerId: 'case-2',
        ),
      ),
    );

    expect(advance.parentTransactionId, isNull);
    expect(advance.ownership?.ownerType, 'orchestration.advance');
    expect(advance.ownership?.ownerId, 'case-2');
    expect(entriesAreBalanced(advance.entries), isTrue);
  });
}
