import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/entity/transaction_group.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_instruction_resolver.dart';
import 'package:smartflow/domain/ledger/valobj/account_amount_allocation.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/posting_instruction.dart';

import '../../../../helper/sequential_id_generator.dart';

void main() {
  final occurredAt = DateTime(2026, 8, 26);
  late PostingEngine engine;

  setUp(() {
    engine = PostingEngine(
      idGenerator: SequentialIdGenerator(prefix: 'allocation'),
    );
  });

  test('expense keeps category and settlement dimensions independent', () {
    final transaction = engine.createExpense(
      ExpenseInstruction(
        amount: _money(120),
        categoryAllocations: [
          _allocation('digital', 100),
          _allocation('clothes', 20),
        ],
        settlementAllocations: [
          _allocation('wechat', 60),
          _allocation('card', 60),
        ],
        occurredAt: occurredAt,
      ),
    );

    expect(
      transaction.lines.map((line) => (line.role, line.accountId, line.amount)),
      [
        (TransactionRole.category, 'digital', _money(100)),
        (TransactionRole.category, 'clothes', _money(20)),
        (TransactionRole.settlementOut, 'wechat', _money(60)),
        (TransactionRole.settlementOut, 'card', _money(60)),
      ],
    );
    expect(
      transaction.entries.map(
        (entry) => (entry.accountId, entry.direction, entry.amount),
      ),
      containsAll([
        ('digital', EntryDirection.debit, _money(100)),
        ('clothes', EntryDirection.debit, _money(20)),
        ('wechat', EntryDirection.credit, _money(60)),
        ('card', EntryDirection.credit, _money(60)),
      ]),
    );

    final resolved =
        const DefaultPostingInstructionResolver().resolve(transaction)
            as ExpenseInstruction;
    expect(_shape(resolved.categoryAllocations), ['digital:100', 'clothes:20']);
    expect(_shape(resolved.settlementAllocations), ['wechat:60', 'card:60']);
  });

  test('ordinary refund allocates categories and receiving accounts', () {
    final parent = engine.createExpense(
      ExpenseInstruction(
        amount: _money(100),
        categoryAllocations: [
          _allocation('food', 70),
          _allocation('drink', 30),
        ],
        settlementAllocations: [_allocation('card', 100)],
        occurredAt: occurredAt,
      ),
    );
    final refund = engine.createRefund(
      instruction: RefundInstruction(
        parentTransactionId: parent.id,
        amount: _money(50),
        categoryAllocations: [
          _allocation('food', 30),
          _allocation('drink', 20),
        ],
        settlementAllocations: [
          _allocation('card', 20),
          _allocation('cash', 30),
        ],
        occurredAt: occurredAt,
      ),
      parent: parent,
    );

    expect(
      refund.entries.map(
        (entry) => (entry.accountId, entry.direction, entry.amount),
      ),
      containsAll([
        ('card', EntryDirection.debit, _money(20)),
        ('cash', EntryDirection.debit, _money(30)),
        ('food', EntryDirection.credit, _money(30)),
        ('drink', EntryDirection.credit, _money(20)),
      ]),
    );
    final resolved = const DefaultPostingInstructionResolver().resolveRefund(
      refund,
    );
    expect(_shape(resolved.categoryAllocations), ['food:30', 'drink:20']);
    expect(_shape(resolved.settlementAllocations), ['card:20', 'cash:30']);
  });

  test('advance refund keeps category facts but credits receivable', () {
    final advance = _advance(engine, occurredAt);
    final refund = engine.createRefund(
      instruction: RefundInstruction(
        parentTransactionId: advance.id,
        amount: _money(40),
        categoryAllocations: [
          _allocation('travel', 25),
          _allocation('meal', 15),
        ],
        settlementAllocations: [
          _allocation('card', 10),
          _allocation('cash', 30),
        ],
        occurredAt: occurredAt,
      ),
      parent: advance,
    );

    expect(
      refund.lines
          .where(
            (line) => line.role == TransactionRole.reimbursementExpenseCategory,
          )
          .map((line) => '${line.accountId}:${line.amount.minorUnits}'),
      ['travel:25', 'meal:15'],
    );
    expect(
      refund.entries.map(
        (entry) => (entry.accountId, entry.direction, entry.amount),
      ),
      containsAll([
        ('card', EntryDirection.debit, _money(10)),
        ('cash', EntryDirection.debit, _money(30)),
        ('receivable', EntryDirection.credit, _money(40)),
      ]),
    );
    expect(refund.entries.any((entry) => entry.accountId == 'travel'), isFalse);
  });

  test('receipt supports multiple receiving accounts', () {
    final advance = _advance(engine, occurredAt);
    final receipt = engine.createReimbursementReceipt(
      instruction: ReimbursementReceiptInstruction(
        advanceTransactionId: advance.id,
        amount: _money(40),
        receivableAccountId: 'receivable',
        settlementAllocations: [
          _allocation('card', 15),
          _allocation('cash', 25),
        ],
        occurredAt: occurredAt,
      ),
      advance: advance,
    );

    expect(
      receipt.entries.map(
        (entry) => (entry.accountId, entry.direction, entry.amount),
      ),
      containsAll([
        ('card', EntryDirection.debit, _money(15)),
        ('cash', EntryDirection.debit, _money(25)),
        ('receivable', EntryDirection.credit, _money(40)),
      ]),
    );
  });

  test('close allocates cash and shortfall categories independently', () {
    final advance = _advance(engine, occurredAt);
    final close = engine.createReimbursementClose(
      instruction: ReimbursementCloseInstruction(
        advanceTransactionId: advance.id,
        actualReceivedAmount: _money(50),
        receivableAccountId: 'receivable',
        settlementAllocations: [
          _allocation('card', 30),
          _allocation('cash', 20),
        ],
        gapExpenseAllocations: [
          _allocation('travel', 20),
          _allocation('meal', 10),
        ],
        occurredAt: occurredAt,
      ),
      advance: advance,
      outstanding: _money(80),
      gapIncomeAccountId: null,
    );

    expect(
      close.entries.map(
        (entry) => (entry.accountId, entry.direction, entry.amount),
      ),
      containsAll([
        ('card', EntryDirection.debit, _money(30)),
        ('cash', EntryDirection.debit, _money(20)),
        ('travel', EntryDirection.debit, _money(20)),
        ('meal', EntryDirection.debit, _money(10)),
        ('receivable', EntryDirection.credit, _money(80)),
      ]),
    );
  });

  test('rejects an allocation dimension whose total does not match', () {
    expect(
      () => engine.createExpense(
        ExpenseInstruction(
          amount: _money(100),
          categoryAllocations: [_allocation('food', 90)],
          settlementAllocations: [_allocation('cash', 100)],
          occurredAt: occurredAt,
        ),
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('group tracks remaining refundable amount per category', () {
    final parent = engine.createExpense(
      ExpenseInstruction(
        amount: _money(100),
        categoryAllocations: [
          _allocation('food', 70),
          _allocation('drink', 30),
        ],
        settlementAllocations: [_allocation('card', 100)],
        occurredAt: occurredAt,
      ),
    );
    final refund = engine.createRefund(
      instruction: RefundInstruction(
        parentTransactionId: parent.id,
        amount: _money(40),
        categoryAllocations: [
          _allocation('food', 25),
          _allocation('drink', 15),
        ],
        settlementAllocations: [_allocation('cash', 40)],
        occurredAt: occurredAt,
      ),
      parent: parent,
    );
    final group = TransactionGroup(
      parentTransaction: parent,
      childTransactions: [refund],
    );

    expect(_shape(group.remainingRefundableCategoryAllocations()), [
      'food:45',
      'drink:15',
    ]);
    expect(
      group.allocationsFitRefundableCategories([_allocation('food', 46)]),
      isFalse,
    );
  });

  test('targeted category replacement preserves unrelated allocations', () {
    final current = ExpenseInstruction(
      amount: _money(100),
      categoryAllocations: [
        _allocation('source', 60),
        _allocation('target', 20),
        _allocation('other', 20),
      ],
      settlementAllocations: [_allocation('cash', 100)],
      occurredAt: occurredAt,
    );

    final edited =
        const CategoryReplacementEditPatch(
              businessPurpose: BusinessPurpose.dailyExpense,
              sourceCategoryId: 'source',
              targetCategoryId: 'target',
            ).applyTo(current)
            as ExpenseInstruction;

    expect(_shape(edited.categoryAllocations), ['target:80', 'other:20']);
  });
}

ReimbursementAdvanceInstruction _advanceInstruction(DateTime occurredAt) {
  return ReimbursementAdvanceInstruction(
    amount: _money(100),
    receivableAccountId: 'receivable',
    categoryAllocations: [_allocation('travel', 70), _allocation('meal', 30)],
    settlementAllocations: [_allocation('card', 60), _allocation('cash', 40)],
    occurredAt: occurredAt,
  );
}

Transaction _advance(PostingEngine engine, DateTime occurredAt) {
  return engine.createReimbursementAdvance(_advanceInstruction(occurredAt));
}

AccountAmountAllocation _allocation(String accountId, int amount) {
  return AccountAmountAllocation(accountId: accountId, amount: _money(amount));
}

Money _money(int amount) => Money(minorUnits: amount);

List<String> _shape(List<AccountAmountAllocation> allocations) {
  return [
    for (final allocation in allocations)
      '${allocation.accountId}:${allocation.amount.minorUnits}',
  ];
}
