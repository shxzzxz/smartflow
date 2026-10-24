import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_rule.dart';
import 'package:smartflow/domain/ledger/valobj/advance_ownership.dart';
import 'package:smartflow/domain/ledger/valobj/account_amount_allocation.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/posting_instruction.dart';
import 'package:smartflow/domain/ledger/valobj/transaction_ownership.dart';

import '../../../../helper/sequential_id_generator.dart';

void main() {
  final occurredAt = DateTime(2026, 10, 22);

  test('itemized AA advance keeps category totals and self-borne shares', () {
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
        management: AdvanceManagement.itemized,
        scenario: AdvanceScenario.aa,
      ),
    );

    expect(advance.ownership?.ownerType, 'advance.itemized');
    expect(advance.ownership?.ownerId, advance.id);
    expect(advance.ownership?.ownerRole, 'aa');
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

  test(
    'account-managed advance belongs to the selected receivable account',
    () {
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
          management: AdvanceManagement.account,
          scenario: AdvanceScenario.reimbursement,
        ),
      );

      expect(advance.parentTransactionId, isNull);
      expect(advance.ownership?.ownerType, 'advance.account');
      expect(advance.ownership?.ownerId, 'receivable');
      expect(advance.ownership?.ownerRole, 'reimbursement');
      expect(entriesAreBalanced(advance.entries), isTrue);
    },
  );

  test('account-managed collection and settlement do not validate a pool', () {
    final engine = PostingEngine(
      idGenerator: SequentialIdGenerator(prefix: 'account'),
    );
    const ownership = TransactionOwnership(
      ownerType: 'advance.account',
      ownerId: 'receivable',
      ownerRole: 'onBehalf',
    );

    final collection = engine.createAdvanceCollection(
      instruction: AdvanceCollectionInstruction.account(
        amount: Money.parse('500.00'),
        receivableAccountId: 'receivable',
        settlementAllocations: singleAllocation(
          accountId: 'bank',
          amount: Money.parse('500.00'),
        ),
        ownership: ownership,
        occurredAt: occurredAt,
      ),
    );
    final settlement = engine.createAdvanceSettlement(
      instruction: AdvanceSettlementInstruction.account(
        actualReceivedAmount: Money.parse('700.00'),
        receivableAccountId: 'receivable',
        settlementAllocations: singleAllocation(
          accountId: 'bank',
          amount: Money.parse('700.00'),
        ),
        gapExpenseAllocations: const [],
        ownership: ownership,
        occurredAt: occurredAt,
      ),
      outstanding: Money.parse('100.00'),
      gapIncomeAccountId: null,
    );

    expect(collection.parentTransactionId, isNull);
    expect(settlement.parentTransactionId, isNull);
    expect(collection.ownership, ownership);
    expect(settlement.ownership, ownership);
    expect(
      settlement.lines
          .where((line) => line.role == TransactionRole.receivable)
          .single
          .amount,
      Money.parse('700.00'),
    );
    expect(
      settlement.lines.any(
        (line) => line.role == TransactionRole.advanceCompensationIncome,
      ),
      isFalse,
    );
    expect(entriesAreBalanced(collection.entries), isTrue);
    expect(entriesAreBalanced(settlement.entries), isTrue);
  });
}
