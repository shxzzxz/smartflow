import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
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
    expect(
      transaction.details.single.type,
      TransactionDetailType.lendingPrincipal,
    );
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
      interestIncomeAccountId: 'interest-income',
    );
    expect(transaction.primaryAmount, Money.parse('85'));
    expect(transaction.isExcludedFromBudget, isFalse);
    expect(transaction.details.map((item) => item.type), [
      TransactionDetailType.receivableCollectionPrincipal,
      TransactionDetailType.receivableCollectionInterest,
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
    expect(withoutInterest.details, hasLength(1));
    expect(withoutInterest.entries, hasLength(2));
  });

  test(
    'collection resolution uses account role when principal equals interest',
    () {
      final transaction = engine.createReceivableCollection(
        ReceivableCollectionInstruction(
          principal: Money.parse('50'),
          interest: Money.parse('50'),
          receivableAccountId: 'receivable',
          receiveAccountId: 'fund',
          occurredAt: DateTime(2026, 8, 20),
        ),
        interestIncomeAccountId: 'interest-income',
      );
      final persisted = transaction.copyWith(
        entries: transaction.entries.reversed.toList(),
      );

      final resolved =
          const DefaultPostingInstructionResolver().resolve(
                persisted,
                accountsById: {
                  'receivable': Account(
                    id: 'receivable',
                    name: '应收',
                    type: AccountType.asset,
                    subtype: AccountSubtype.receivable,
                    balance: Money.zero(),
                  ),
                  'fund': Account(
                    id: 'fund',
                    name: '资金',
                    type: AccountType.asset,
                    subtype: AccountSubtype.fund,
                    balance: Money.zero(),
                  ),
                  'interest-income': Account(
                    id: 'interest-income',
                    name: '利息收入',
                    type: AccountType.income,
                    balance: Money.zero(),
                  ),
                },
              )
              as ReceivableCollectionInstruction;

      expect(resolved.receivableAccountId, 'receivable');
      expect(resolved.receiveAccountId, 'fund');
    },
  );

  test('bad debt and debt relief use expense and income counterparts', () {
    final badDebt = engine.createBadDebt(
      BadDebtInstruction(
        amount: Money.parse('20'),
        receivableAccountId: 'receivable',
        occurredAt: DateTime(2026, 8, 20),
      ),
      badDebtExpenseAccountId: 'bad-debt-expense',
    );
    final relief = engine.createDebtRelief(
      DebtReliefInstruction(
        amount: Money.parse('30'),
        liabilityAccountId: 'payable',
        occurredAt: DateTime(2026, 8, 20),
      ),
      debtReliefIncomeAccountId: 'relief-income',
    );

    expect(entriesAreBalanced(badDebt.entries), isTrue);
    expect(entriesAreBalanced(relief.entries), isTrue);
    expect(badDebt.details.single.type, TransactionDetailType.badDebtMain);
    expect(relief.details.single.type, TransactionDetailType.debtReliefMain);
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
      badDebtExpenseAccountId: 'bad-debt-expense',
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
      debtReliefIncomeAccountId: 'relief-income',
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
