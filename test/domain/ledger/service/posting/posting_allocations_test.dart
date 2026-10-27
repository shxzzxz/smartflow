import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/entity/transaction_group.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_instruction_resolver.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_rule.dart';
import 'package:smartflow/domain/ledger/valobj/account_amount_allocation.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/posting_instruction.dart';
import 'package:smartflow/domain/ledger/valobj/transaction_ownership.dart';

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

  test('income keeps category and settlement dimensions independent', () {
    final transaction = engine.createIncome(
      IncomeInstruction(
        amount: _money(120),
        categoryAllocations: [
          _allocation('salary', 100),
          _allocation('bonus', 20),
        ],
        settlementAllocations: [
          _allocation('bank', 70),
          _allocation('cash', 50),
        ],
        occurredAt: occurredAt,
      ),
    );

    expect(
      transaction.lines.map((line) => (line.role, line.accountId, line.amount)),
      [
        (TransactionRole.category, 'salary', _money(100)),
        (TransactionRole.category, 'bonus', _money(20)),
        (TransactionRole.settlementIn, 'bank', _money(70)),
        (TransactionRole.settlementIn, 'cash', _money(50)),
      ],
    );
    expect(
      transaction.entries.map(
        (entry) => (entry.accountId, entry.direction, entry.amount),
      ),
      containsAll([
        ('salary', EntryDirection.credit, _money(100)),
        ('bonus', EntryDirection.credit, _money(20)),
        ('bank', EntryDirection.debit, _money(70)),
        ('cash', EntryDirection.debit, _money(50)),
      ]),
    );

    final resolved =
        const DefaultPostingInstructionResolver().resolve(transaction)
            as IncomeInstruction;
    expect(_shape(resolved.categoryAllocations), ['salary:100', 'bonus:20']);
    expect(_shape(resolved.settlementAllocations), ['bank:70', 'cash:50']);
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

  test(
    'advance refund keeps category facts and reduces the parent receivable',
    () {
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
              (line) => line.role == TransactionRole.advanceExpenseCategory,
            )
            .map((line) => '${line.accountId}:${line.amount.minorUnits}'),
        ['travel:25', 'meal:15'],
      );
      expect(
        refund.lines
            .where((line) => line.role == TransactionRole.receivable)
            .map((line) => '${line.accountId}:${line.amount.minorUnits}'),
        ['receivable:40'],
      );
      expect(
        refund.lines.where((line) => line.role == TransactionRole.refundOffset),
        isEmpty,
      );
      final resolved = const DefaultPostingInstructionResolver().resolveRefund(
        refund,
      );
      final recreated = engine.createRefund(
        instruction: resolved,
        parent: advance,
      );
      expect(sameLines(recreated.lines, refund.lines), isTrue);
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
      expect(
        refund.entries
            .where(
              (entry) =>
                  entry.accountId == 'receivable' &&
                  entry.direction == EntryDirection.credit,
            )
            .length,
        1,
      );
      expect(
        refund.entries.any((entry) => entry.accountId == 'travel'),
        isFalse,
      );

      final replay = engine.postEntries(
        transactionId: refund.id,
        businessPurpose: refund.businessPurpose,
        lines: refund.lines,
        accountTypes: const {
          'card': AccountType.asset,
          'cash': AccountType.asset,
          'receivable': AccountType.asset,
        },
      );
      expect(sameEntries(replay, refund.entries), isTrue);

      final group = TransactionGroup(
        parentTransaction: advance,
        childTransactions: [refund],
      );
      expect(_shape(group.refundSummary!.refundedCategoryAllocations), [
        'travel:25',
        'meal:15',
      ]);
    },
  );

  test('advance refund splits self-borne and receivable reductions', () {
    final advance = _advance(engine, occurredAt);
    final refund = engine.createRefund(
      instruction: RefundInstruction(
        parentTransactionId: advance.id,
        amount: _money(40),
        categoryAllocations: [
          _allocation('travel', 25),
          _allocation('meal', 15),
        ],
        selfBorneAllocations: [_allocation('travel', 10)],
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
          .where((line) => line.role == TransactionRole.advanceSelfBorne)
          .map((line) => '${line.accountId}:${line.amount.minorUnits}'),
      ['travel:10'],
    );
    expect(
      refund.lines
          .where((line) => line.role == TransactionRole.receivable)
          .map((line) => '${line.accountId}:${line.amount.minorUnits}'),
      ['receivable:30'],
    );
    expect(
      refund.entries.map(
        (entry) => (entry.accountId, entry.direction, entry.amount),
      ),
      containsAll([
        ('card', EntryDirection.debit, _money(10)),
        ('cash', EntryDirection.debit, _money(30)),
        ('travel', EntryDirection.credit, _money(10)),
        ('receivable', EntryDirection.credit, _money(30)),
      ]),
    );
    expect(entriesAreBalanced(refund.entries), isTrue);

    final resolved = const DefaultPostingInstructionResolver().resolveRefund(
      refund,
    );
    expect(_shape(resolved.selfBorneAllocations), ['travel:10']);
  });

  test('receipt supports multiple receiving accounts', () {
    final advance = _advance(engine, occurredAt);
    final receipt = engine.createAdvanceCollection(
      instruction: AdvanceCollectionInstruction(
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
    final close = engine.createAdvanceSettlement(
      instruction: AdvanceSettlementInstruction(
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

  test('targeted category replacement updates one income allocation', () {
    final current = IncomeInstruction(
      amount: _money(100),
      categoryAllocations: [
        _allocation('salary', 60),
        _allocation('bonus', 20),
        _allocation('other', 20),
      ],
      settlementAllocations: [_allocation('bank', 100)],
      occurredAt: occurredAt,
    );

    final edited =
        const CategoryReplacementEditPatch(
              businessPurpose: BusinessPurpose.dailyIncome,
              sourceCategoryId: 'salary',
              targetCategoryId: 'bonus',
            ).applyTo(current)
            as IncomeInstruction;

    expect(_shape(edited.categoryAllocations), ['bonus:80', 'other:20']);
    expect(_shape(edited.settlementAllocations), ['bank:100']);
  });

  test(
    'targeted category replacement updates advance totals and self-borne shares',
    () {
      final current = AdvanceInstruction(
        amount: _money(100),
        advanceAmount: _money(70),
        receivableAccountId: 'receivable',
        categoryAllocations: [
          _allocation('travel', 70),
          _allocation('meal', 30),
        ],
        selfBorneAllocations: [
          _allocation('travel', 20),
          _allocation('meal', 10),
        ],
        settlementAllocations: [_allocation('cash', 100)],
        occurredAt: DateTime(2026, 10, 22),
      );

      final edited =
          const CategoryReplacementEditPatch(
                businessPurpose: BusinessPurpose.advance,
                sourceCategoryId: 'travel',
                targetCategoryId: 'trip',
              ).applyTo(current)
              as AdvanceInstruction;

      expect(_shape(edited.categoryAllocations), ['trip:70', 'meal:30']);
      expect(_shape(edited.selfBorneAllocations), ['trip:20', 'meal:10']);
    },
  );
}

AdvanceInstruction _advanceInstruction(DateTime occurredAt) {
  return AdvanceInstruction(
    amount: _money(100),
    receivableAccountId: 'receivable',
    categoryAllocations: [_allocation('travel', 70), _allocation('meal', 30)],
    settlementAllocations: [_allocation('card', 60), _allocation('cash', 40)],
    occurredAt: occurredAt,
    ownership: const TransactionOwnership(
      ownerType: 'orchestration.advance',
      ownerId: 'case',
    ),
  );
}

Transaction _advance(PostingEngine engine, DateTime occurredAt) {
  return engine.createAdvance(_advanceInstruction(occurredAt));
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
