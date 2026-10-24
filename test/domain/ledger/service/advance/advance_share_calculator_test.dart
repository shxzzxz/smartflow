import 'package:test/test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/entity/transaction_group.dart';
import 'package:smartflow/domain/ledger/service/advance/advance_share_calculator.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/domain/ledger/valobj/account_amount_allocation.dart';
import 'package:smartflow/domain/ledger/valobj/advance_ownership.dart';
import 'package:smartflow/domain/ledger/valobj/posting_instruction.dart';

import '../../../../helper/sequential_id_generator.dart';

void main() {
  const policy = AdvanceShareCalculator();
  final occurredAt = DateTime(2026, 10, 23);
  final engine = PostingEngine(
    idGenerator: SequentialIdGenerator(prefix: 'share'),
  );

  test(
    'AA entry derives participant shares and allocates self-borne by category',
    () {
      final share = policy.splitForEntry(
        scenario: AdvanceScenario.aa,
        total: _money(7000),
        aaPeopleCount: 3,
        categoryAllocations: [
          _allocation('food', 4000),
          _allocation('travel', 3000),
        ],
      );

      expect(share.aaPeopleCount, 3);
      expect(share.selfBorneAmount, _money(2332));
      expect(share.advanceAmount, _money(4668));
      expect(_shape(share.selfBorneAllocations), ['food:1332', 'travel:1000']);
    },
  );

  test('AA participant count is recovered from total and advance amount', () {
    expect(
      policy.inferAaPeopleCount(
        total: _money(7000),
        advanceAmount: _money(4668),
      ),
      3,
    );
  });

  test(
    'AA refund recomputes self-borne and advance against remaining total',
    () {
      final group = TransactionGroup(
        parentTransaction: _aaAdvance(engine, occurredAt),
        childTransactions: const [],
      );

      final share = policy.splitForRefund(
        group: group,
        refundAmount: _money(2000),
        refundCategoryAllocations: [
          _allocation('food', 1000),
          _allocation('travel', 1000),
        ],
      );

      expect(share.aaPeopleCount, 3);
      expect(share.selfBorneAmount, _money(666));
      expect(share.advanceAmount, _money(1334));
      expect(_shape(share.selfBorneAllocations), ['food:333', 'travel:333']);

      final refund = engine.createRefund(
        instruction: RefundInstruction(
          parentTransactionId: group.parentTransaction.id,
          amount: _money(2000),
          categoryAllocations: [
            _allocation('food', 1000),
            _allocation('travel', 1000),
          ],
          selfBorneAllocations: share.selfBorneAllocations,
          settlementAllocations: [_allocation('cash', 2000)],
          occurredAt: occurredAt,
        ),
        parent: group.parentTransaction,
      );
      final summary = TransactionGroup(
        parentTransaction: group.parentTransaction,
        childTransactions: [refund],
      ).advanceSummary!;
      expect(summary.refundedAmount, _money(2000));
      expect(summary.advanceRefundedAmount, _money(1334));
      expect(summary.refundableAmount, _money(5000));
      expect(summary.outstanding, _money(3334));
      expect(summary.gapAmount, Money.zero());
    },
  );

  test('ordinary advance refund keeps the current self-borne ratio', () {
    final parent = engine.createAdvance(
      AdvanceInstruction(
        amount: _money(7000),
        advanceAmount: _money(5000),
        receivableAccountId: 'receivable',
        categoryAllocations: [
          _allocation('food', 4000),
          _allocation('travel', 3000),
        ],
        selfBorneAllocations: [
          _allocation('food', 1142),
          _allocation('travel', 858),
        ],
        settlementAllocations: [_allocation('cash', 7000)],
        occurredAt: occurredAt,
        scenario: AdvanceScenario.reimbursement,
      ),
    );
    final group = TransactionGroup(
      parentTransaction: parent,
      childTransactions: const [],
    );

    final share = policy.splitForRefund(
      group: group,
      refundAmount: _money(700),
      refundCategoryAllocations: [
        _allocation('food', 400),
        _allocation('travel', 300),
      ],
    );

    expect(share.selfBorneAmount, _money(200));
    expect(share.advanceAmount, _money(500));
    expect(_shape(share.selfBorneAllocations), ['food:114', 'travel:86']);
  });

  test('AA refund uses facts excluding the refund being edited', () {
    final parent = _aaAdvance(engine, occurredAt);
    final refund = engine.createRefund(
      instruction: RefundInstruction(
        parentTransactionId: parent.id,
        amount: _money(2000),
        categoryAllocations: [
          _allocation('food', 1000),
          _allocation('travel', 1000),
        ],
        selfBorneAllocations: [
          _allocation('food', 333),
          _allocation('travel', 333),
        ],
        settlementAllocations: [_allocation('cash', 2000)],
        occurredAt: occurredAt,
      ),
      parent: parent,
    );
    final group = TransactionGroup(
      parentTransaction: parent,
      childTransactions: [refund],
    );

    final share = policy.splitForRefund(
      group: group,
      refundAmount: _money(1000),
      refundCategoryAllocations: [_allocation('food', 1000)],
      excludingRefundTransactionId: refund.id,
    );

    expect(share.selfBorneAmount, _money(332));
    expect(share.advanceAmount, _money(668));
  });
}

Transaction _aaAdvance(PostingEngine engine, DateTime occurredAt) {
  return engine.createAdvance(
    AdvanceInstruction(
      amount: _money(7000),
      advanceAmount: _money(4668),
      receivableAccountId: 'receivable',
      categoryAllocations: [
        _allocation('food', 4000),
        _allocation('travel', 3000),
      ],
      selfBorneAllocations: [
        _allocation('food', 1332),
        _allocation('travel', 1000),
      ],
      settlementAllocations: [_allocation('cash', 7000)],
      occurredAt: occurredAt,
      scenario: AdvanceScenario.aa,
    ),
  );
}

AccountAmountAllocation _allocation(String accountId, int minorUnits) {
  return AccountAmountAllocation(
    accountId: accountId,
    amount: _money(minorUnits),
  );
}

Money _money(int minorUnits) => Money(minorUnits: minorUnits);

List<String> _shape(Iterable<AccountAmountAllocation> allocations) {
  return [
    for (final allocation in allocations)
      '${allocation.accountId}:${allocation.amount.minorUnits}',
  ];
}
