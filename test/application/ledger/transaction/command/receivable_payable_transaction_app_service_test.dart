import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/transaction/command/transaction_command.dart';
import 'package:smartflow/application/ledger/transaction/command/transaction_edit_app_service.dart';
import 'package:smartflow/application/ledger/transaction/command/transaction_ledger_writer.dart';
import 'package:smartflow/application/ledger/transaction/command/transaction_posting_app_service.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_account_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_posting_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_system_account_resolver.dart';

import '../../../../helper/fake_transaction_tag_repository.dart';
import '../../../../helper/sequential_id_generator.dart';
import '../../../../helper/test_app_database.dart';

void main() {
  test('lending and collection create, edit, and delete atomically', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.close);

    final lending = await fixture.posting.createLending(
      CreateLendingCommand(
        amount: Money.parse('200'),
        receivableAccountId: 'receivable',
        paidFromAccountId: 'fund',
        occurredAt: DateTime(2026, 8, 20),
      ),
    );
    await fixture.editing.editLending(
      EditLendingCommand(
        transactionId: lending.transactionId,
        amount: Money.parse('250'),
      ),
    );
    expect(await fixture.balance('fund'), Money.parse('-250'));
    expect(await fixture.balance('receivable'), Money.parse('250'));

    final collection = await fixture.posting.createReceivableCollection(
      CreateReceivableCollectionCommand(
        principal: Money.parse('50'),
        interest: Money.parse('5'),
        receivableAccountId: 'receivable',
        receiveAccountId: 'fund',
        occurredAt: DateTime(2026, 8, 21),
      ),
    );
    await fixture.editing.editReceivableCollection(
      EditReceivableCollectionCommand(
        transactionId: collection.transactionId,
        principal: Money.parse('80'),
        interest: Money.parse('8'),
      ),
    );
    expect(await fixture.balance('fund'), Money.parse('-162'));
    expect(await fixture.balance('receivable'), Money.parse('170'));

    await fixture.editing.deleteTransaction(
      DeleteTransactionCommand(transactionId: collection.transactionId),
    );
    await fixture.editing.deleteTransaction(
      DeleteTransactionCommand(transactionId: lending.transactionId),
    );
    expect(await fixture.balance('fund'), Money.zero());
    expect(await fixture.balance('receivable'), Money.zero());
    expect(
      await fixture.transactions.findById(collection.transactionId),
      isNull,
    );
    expect(await fixture.transactions.findById(lending.transactionId), isNull);
  });

  test(
    'bad debt edit restores its old balance impact before validation',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.close);
      await fixture.posting.createLending(
        CreateLendingCommand(
          amount: Money.parse('100'),
          receivableAccountId: 'receivable',
          paidFromAccountId: 'fund',
          occurredAt: DateTime(2026, 8, 20),
        ),
      );
      final badDebt = await fixture.posting.createBadDebt(
        CreateBadDebtCommand(
          amount: Money.parse('40'),
          receivableAccountId: 'receivable',
          occurredAt: DateTime(2026, 8, 21),
        ),
      );

      await fixture.editing.editBadDebt(
        EditBadDebtCommand(
          transactionId: badDebt.transactionId,
          amount: Money.parse('100'),
        ),
      );
      expect(await fixture.balance('receivable'), Money.zero());

      await expectLater(
        fixture.editing.editBadDebt(
          EditBadDebtCommand(
            transactionId: badDebt.transactionId,
            amount: Money.parse('100.01'),
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
      expect(await fixture.balance('receivable'), Money.zero());

      await fixture.editing.deleteTransaction(
        DeleteTransactionCommand(transactionId: badDebt.transactionId),
      );
      expect(await fixture.balance('receivable'), Money.parse('100'));
    },
  );

  test(
    'debt relief edit restores its old balance impact before validation',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.close);
      await fixture.posting.createBorrowing(
        CreateBorrowingCommand(
          amount: Money.parse('100'),
          liabilityAccountId: 'payable',
          receiveAccountId: 'fund',
          occurredAt: DateTime(2026, 8, 20),
        ),
      );
      final relief = await fixture.posting.createDebtRelief(
        CreateDebtReliefCommand(
          amount: Money.parse('40'),
          liabilityAccountId: 'payable',
          occurredAt: DateTime(2026, 8, 21),
        ),
      );

      await fixture.editing.editDebtRelief(
        EditDebtReliefCommand(
          transactionId: relief.transactionId,
          amount: Money.parse('100'),
        ),
      );
      expect(await fixture.balance('payable'), Money.zero());

      await expectLater(
        fixture.editing.editDebtRelief(
          EditDebtReliefCommand(
            transactionId: relief.transactionId,
            amount: Money.parse('100.01'),
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
      expect(await fixture.balance('payable'), Money.zero());

      await fixture.editing.deleteTransaction(
        DeleteTransactionCommand(transactionId: relief.transactionId),
      );
      expect(await fixture.balance('payable'), Money.parse('100'));
    },
  );

  test('borrowing and repayment accept payable and loan subtypes', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.close);

    for (final liabilityId in ['payable', 'loan']) {
      await fixture.posting.createBorrowing(
        CreateBorrowingCommand(
          amount: Money.parse('100'),
          liabilityAccountId: liabilityId,
          receiveAccountId: 'fund',
          occurredAt: DateTime(2026, 8, 20),
        ),
      );
      await fixture.posting.createRepayment(
        CreateRepaymentCommand(
          principal: Money.parse('30'),
          liabilityAccountId: liabilityId,
          paidFromAccountId: 'fund',
          occurredAt: DateTime(2026, 8, 21),
        ),
      );
      expect(await fixture.balance(liabilityId), Money.parse('70'));
    }
  });
}

class _Fixture {
  _Fixture._({
    required this.database,
    required this.accounts,
    required this.transactions,
    required this.posting,
    required this.editing,
  });

  final AppDatabase database;
  final DriftAccountRepository accounts;
  final DriftPostingRepository transactions;
  final TransactionPostingAppServiceImpl posting;
  final TransactionEditAppServiceImpl editing;

  static Future<_Fixture> create() async {
    final database = createTestDatabase();
    final accounts = DriftAccountRepository(database);
    await accounts.create(
      Account(
        id: 'fund',
        name: 'Fund',
        type: AccountType.asset,
        subtype: AccountSubtype.fund,
        profileKey: 'ledger.fund',
        balance: Money.zero(),
      ),
    );
    await accounts.create(
      Account(
        id: 'receivable',
        name: 'Receivable',
        type: AccountType.asset,
        subtype: AccountSubtype.receivable,
        profileKey: 'ledger.receivable',
        balance: Money.zero(),
      ),
    );
    await accounts.create(
      Account(
        id: 'payable',
        name: 'Payable',
        type: AccountType.liability,
        subtype: AccountSubtype.payable,
        profileKey: 'ledger.payable',
        balance: Money.zero(),
      ),
    );
    await accounts.create(
      Account(
        id: 'loan',
        name: 'Loan',
        type: AccountType.liability,
        subtype: AccountSubtype.loan,
        profileKey: 'credit.loan',
        balance: Money.zero(),
      ),
    );

    final transactions = DriftPostingRepository(database);
    final runner = DriftTransactionRunner(database);
    final resolver = DriftSystemAccountResolver(database);
    final ids = SequentialIdGenerator(prefix: 'receivable-payable');
    final writer = TransactionLedgerWriter(
      transactionRunner: runner,
      transactionRepository: transactions,
      transactionGroupRepository: transactions,
      accountRepository: accounts,
      transactionTagRepository: FakeTransactionTagRepository(),
    );
    final posting = TransactionPostingAppServiceImpl(
      accountRepository: accounts,
      transactionGroupRepository: transactions,
      systemAccountResolver: resolver,
      ledgerWriter: writer,
      idGenerator: ids,
    );
    final editing = TransactionEditAppServiceImpl(
      accountRepository: accounts,
      transactionGroupRepository: transactions,
      systemAccountResolver: resolver,
      ledgerWriter: writer,
      idGenerator: ids,
    );
    return _Fixture._(
      database: database,
      accounts: accounts,
      transactions: transactions,
      posting: posting,
      editing: editing,
    );
  }

  Future<Money> balance(String accountId) async =>
      (await accounts.findById(accountId))!.balance;

  Future<void> close() => database.close();
}
