import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/result/result.dart';
import 'package:smartflow/data/app_database.dart';
import 'package:smartflow/infrastructure/accounting/repositories/drift_account_repository.dart';
import 'package:smartflow/infrastructure/accounting/repositories/drift_balance_aggregate_repository.dart';
import 'package:smartflow/infrastructure/accounting/repositories/drift_entry_read_repository.dart';
import 'package:smartflow/infrastructure/accounting/repositories/drift_posting_repository.dart';
import 'package:smartflow/infrastructure/accounting/repositories/drift_system_account_resolver.dart';
import 'package:smartflow/infrastructure/accounting/repositories/drift_transaction_detail_read_repository.dart';
import 'package:smartflow/infrastructure/accounting/repositories/drift_transaction_read_repository.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/application/accounting/accounting_api.dart';
import 'package:smartflow/domain/accounting/ledger/poster.dart';
import 'package:smartflow/application/accounting/use_cases/receipt_builder.dart';

import '../../../helpers/test_app_database.dart';

void main() {
  group('DriftAccountRepository', () {
    late AppDatabase database;
    late DriftSystemAccountResolver systemAccounts;
    late DriftAccountRepository repository;
    late TransactionService transactionService;
    late AccountServiceImpl service;

    setUp(() {
      database = createTestDatabase();
      systemAccounts = DriftSystemAccountResolver(database);
      repository = DriftAccountRepository(database);
      final queryService = TransactionQueryServiceImpl(
        transactionRead: DriftTransactionReadRepository(database),
        entryRead: DriftEntryReadRepository(database),
        detailRead: DriftTransactionDetailReadRepository(database),
        balanceAggregate: DriftBalanceAggregateRepository(database),
      );
      final postingRepository = DriftPostingRepository(database);
      transactionService = TransactionServiceImpl(
        poster: PosterImpl(postingRepository),
        receiptBuilder: ReceiptBuilder(
          accounts: repository,
          query: queryService,
          systemAccounts: systemAccounts,
        ),
        accountRepository: repository,
        transactionQueryService: queryService,
        postingRepository: postingRepository,
        transactionRunner: DriftTransactionRunner(database),
      );
      service = AccountServiceImpl(
        repository,
        transactionRunner: DriftTransactionRunner(database),
        transactions: transactionService,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'creates an account with opening balance in one posting chain',
      () async {
        final result = await service.createAccount(
          CreateAccountCommand(
            name: '招行',
            type: AccountType.asset,
            openingBalance: const Money(minorUnits: 5000000),
          ),
        );

        expect(result, isA<Success>());
        final account = (result as Success).value;
        expect(account.balance, const Money(minorUnits: 5000000));

        final transactions = await database.select(database.transactions).get();
        final details =
            await database.select(database.transactionDetails).get();
        final entries = await database.select(database.entries).get();
        final systemAccountRows =
            await (database.select(database.accounts)..where(
              (row) => row.systemKey.equalsValue(SystemKey.openingBalance),
            )).get();

        expect(transactions, hasLength(1));
        expect(
          transactions.single.businessPurpose,
          BusinessPurpose.openingBalance,
        );
        expect(
          details.single.detailType,
          TransactionDetailType.openingBalanceMain,
        );
        expect(entries, hasLength(2));
        expect(systemAccountRows.single.accountType, AccountType.equity);
        expect(systemAccountRows.single.balanceMinor, 5000000);
      },
    );

    test('edits fund account balance through balance adjustment', () async {
      final createResult = await service.createAccount(
        CreateAccountCommand(
          name: '招行',
          type: AccountType.asset,
          openingBalance: const Money(minorUnits: 500000),
        ),
      );
      final account = (createResult as Success).value;

      final editResult = await service.editAccount(
        EditAccountCommand(
          id: account.id,
          name: '招商银行',
          targetBalance: const Money(minorUnits: 700000),
        ),
      );

      expect(editResult, isA<Success>());
      final updated = await repository.findAccountById(account.id);
      expect(updated!.name, '招商银行');
      expect(updated.balance, const Money(minorUnits: 700000));

      final transactions =
          await (database.select(database.transactions)..where(
            (row) => row.businessPurpose.equalsValue(
              BusinessPurpose.balanceAdjustment,
            ),
          )).get();
      final details =
          await (database.select(database.transactionDetails)..where(
            (row) => row.detailType.equalsValue(
              TransactionDetailType.balanceAdjustmentMain,
            ),
          )).get();

      expect(transactions, hasLength(1));
      expect(transactions.single.primaryAmountMinor, 200000);
      expect(details.single.amountMinor, 200000);
    });

    test('edits credit account debt through balance adjustment', () async {
      final createResult = await service.createAccount(
        CreateAccountCommand(
          name: '花呗',
          type: AccountType.liability,
          subtype: AccountSubtype.consumerCredit,
          openingBalance: const Money(minorUnits: 1000000),
        ),
      );
      final account = (createResult as Success).value;

      final editResult = await service.editAccount(
        EditAccountCommand(
          id: account.id,
          name: '花呗',
          targetBalance: const Money(minorUnits: 800000),
        ),
      );

      expect(editResult, isA<Success>());
      final updated = await repository.findAccountById(account.id);
      expect(updated!.balance, const Money(minorUnits: 800000));

      final adjustmentEntries =
          await (database.select(database.entries).join([
            innerJoin(
              database.transactions,
              database.transactions.id.equalsExp(
                database.entries.transactionId,
              ),
            ),
          ])..where(
            database.transactions.businessPurpose.equalsValue(
              BusinessPurpose.balanceAdjustment,
            ),
          )).get();
      final liabilityEntry = adjustmentEntries
          .map((row) => row.readTable(database.entries))
          .singleWhere((entry) => entry.accountId == account.id);

      expect(liabilityEntry.direction, EntryDirection.debit);
      expect(liabilityEntry.amountMinor, 200000);
    });

    test(
      'allows loan account opening balance and balance adjustment',
      () async {
        final createResult = await service.createAccount(
          CreateAccountCommand(
            name: '房贷',
            type: AccountType.liability,
            subtype: AccountSubtype.loan,
            openingBalance: const Money(minorUnits: 1000000),
          ),
        );
        expect(createResult, isA<Success>());
        final account = (createResult as Success).value;
        final afterCreate = await repository.findAccountById(account.id);
        expect(afterCreate!.balance, const Money(minorUnits: 1000000));

        final editResult = await service.editAccount(
          EditAccountCommand(
            id: account.id,
            name: account.name,
            targetBalance: const Money(minorUnits: 800000),
          ),
        );
        expect(editResult, isA<Success>());
        final afterEdit = await repository.findAccountById(account.id);
        expect(afterEdit!.balance, const Money(minorUnits: 800000));
      },
    );

    test('creates reimbursement account as asset subtype', () async {
      final result = await service.createAccount(
        const CreateAccountCommand(
          name: '公司报销',
          type: AccountType.asset,
          subtype: AccountSubtype.reimbursement,
        ),
      );

      expect(result, isA<Success>());
      final account = (result as Success).value;
      expect(account.type, AccountType.asset);
      expect(account.subtype, AccountSubtype.reimbursement);
    });

    test('builds income and expense category trees', () async {
      final categoryService = CategoryServiceImpl(repository);
      final parentResult = await categoryService.createCategory(
        const CreateCategoryCommand(name: '餐饮', type: AccountType.expense),
      );
      final parent = (parentResult as Success).value;

      await categoryService.createCategory(
        CreateCategoryCommand(
          name: '咖啡',
          type: AccountType.expense,
          parentId: parent.id,
        ),
      );

      final tree =
          await categoryService.watchCategoryTree(AccountType.expense).first;

      final node = tree.singleWhere((node) => node.account.name == '餐饮');
      expect(node.children.single.name, '咖啡');
    });
  });
}
