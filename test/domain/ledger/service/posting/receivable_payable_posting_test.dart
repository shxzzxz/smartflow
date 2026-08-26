import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_instruction_resolver.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_rule.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/posting_instruction.dart';

import '../../../../helper/sequential_id_generator.dart';

void main() {
  late PostingEngine engine;
  setUp(() {
    engine = PostingEngine(idGenerator: SequentialIdGenerator(prefix: 'new'));
  });

  test('lending moves principal from fund to receivable', () {
    final transaction = engine.createLending(
      LendingInstruction(
        amount: Money.parse('200'),
        receivableAccountId: 'receivable',
        paidFromAccountId: 'fund',
        occurredAt: DateTime(2026, 8, 20),
      ),
    );

    expect(transaction.businessPurpose, BusinessPurpose.lending);
    expect(transaction.primaryAmount, Money.parse('200'));
    expect(transaction.isExcludedFromBudget, isFalse);
    expect(transaction.lines.map((line) => line.role), [
      TransactionRole.receivable,
      TransactionRole.settlementOut,
    ]);
    expect(entriesAreBalanced(transaction.entries), isTrue);
    expect(
      transaction.entries.map((entry) => (entry.accountId, entry.direction)),
      containsAll([
        ('receivable', EntryDirection.debit),
        ('fund', EntryDirection.credit),
      ]),
    );
  });

  test('collection records principal and interest without empty lines', () {
    final transaction = engine.createReceivableCollection(
      ReceivableCollectionInstruction(
        principal: Money.parse('80'),
        interest: Money.parse('5'),
        receivableAccountId: 'receivable',
        receiveAccountId: 'fund',
        occurredAt: DateTime(2026, 8, 20),
      ),
      systemAccountIds: const {SystemKey.interestIncome: 'interest-income'},
    );
    expect(transaction.primaryAmount, Money.parse('85'));
    expect(transaction.isExcludedFromBudget, isFalse);
    expect(transaction.lines.map((line) => line.role), [
      TransactionRole.receivable,
      TransactionRole.interest,
      TransactionRole.settlementIn,
    ]);
    expect(entriesAreBalanced(transaction.entries), isTrue);

    final withoutInterest = engine.createReceivableCollection(
      ReceivableCollectionInstruction(
        principal: Money.parse('80'),
        receivableAccountId: 'receivable',
        receiveAccountId: 'fund',
        occurredAt: DateTime(2026, 8, 20),
      ),
    );
    expect(withoutInterest.lines, hasLength(2));
    expect(withoutInterest.entries, hasLength(2));
  });

  test('collection resolution reads lines, not entry order', () {
    final transaction = engine.createReceivableCollection(
      ReceivableCollectionInstruction(
        principal: Money.parse('50'),
        interest: Money.parse('50'),
        receivableAccountId: 'receivable',
        receiveAccountId: 'fund',
        occurredAt: DateTime(2026, 8, 20),
      ),
      systemAccountIds: const {SystemKey.interestIncome: 'interest-income'},
    );
    final persisted = transaction.copyWith(
      entries: transaction.entries.reversed.toList(),
    );

    final resolved =
        const DefaultPostingInstructionResolver().resolve(persisted)
            as ReceivableCollectionInstruction;

    expect(resolved.receivableAccountId, 'receivable');
    expect(resolved.receiveAccountId, 'fund');
    expect(resolved.principal, Money.parse('50'));
    expect(resolved.interest, Money.parse('50'));
  });

  test('bad debt and debt relief use expense and income counterparts', () {
    final badDebt = engine.createBadDebt(
      BadDebtInstruction(
        amount: Money.parse('20'),
        receivableAccountId: 'receivable',
        occurredAt: DateTime(2026, 8, 20),
      ),
      systemAccountIds: const {SystemKey.badDebtExpense: 'bad-debt-expense'},
    );
    final relief = engine.createDebtRelief(
      DebtReliefInstruction(
        amount: Money.parse('30'),
        liabilityAccountId: 'payable',
        occurredAt: DateTime(2026, 8, 20),
      ),
      systemAccountIds: const {SystemKey.debtReliefIncome: 'relief-income'},
    );

    expect(entriesAreBalanced(badDebt.entries), isTrue);
    expect(entriesAreBalanced(relief.entries), isTrue);
    expect(badDebt.lines.single.role, TransactionRole.receivable);
    expect(relief.lines.single.role, TransactionRole.liability);
    expect(badDebt.isExcludedFromBudget, isFalse);
    expect(relief.isExcludedFromBudget, isFalse);
  });

  test('bad debt reporting flags can be edited like an expense', () {
    final badDebt = engine.createBadDebt(
      BadDebtInstruction(
        amount: Money.parse('20'),
        receivableAccountId: 'receivable',
        occurredAt: DateTime(2026, 8, 20),
      ),
      systemAccountIds: const {SystemKey.badDebtExpense: 'bad-debt-expense'},
    );
    badDebt.updateReportingFlags(
      isExcludedFromStats: true,
      isExcludedFromBudget: true,
      parentPurpose: badDebt.businessPurpose,
    );
    expect(badDebt.isExcludedFromStats, isTrue);
    expect(badDebt.isExcludedFromBudget, isTrue);
  });

  test('debt relief reporting flags behave like income', () {
    final relief = engine.createDebtRelief(
      DebtReliefInstruction(
        amount: Money.parse('30'),
        liabilityAccountId: 'payable',
        occurredAt: DateTime(2026, 8, 20),
      ),
      systemAccountIds: const {SystemKey.debtReliefIncome: 'relief-income'},
    );

    relief.updateReportingFlags(
      isExcludedFromStats: true,
      isExcludedFromBudget: true,
      parentPurpose: relief.businessPurpose,
    );
    expect(relief.isExcludedFromStats, isTrue);
    expect(relief.isExcludedFromBudget, isFalse);
  });
}
