import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/result/result.dart';
import 'package:smartflow/data/app_database.dart';
import 'package:smartflow/data/accounting/repositories/drift_account_repository.dart';
import 'package:smartflow/data/accounting/repositories/drift_posting_repository.dart';
import 'package:smartflow/data/accounting/repositories/drift_system_account_resolver.dart';
import 'package:smartflow/data/accounting/repositories/drift_transaction_query_repository.dart';
import 'package:smartflow/data/transaction/drift_transaction_runner.dart';
import 'package:smartflow/domain/accounting/accounting_api.dart';
import 'package:smartflow/domain/accounting/ledger/poster.dart';

import '../../../helpers/test_app_database.dart';

void main() {
  group('DriftTransactionQueryRepository', () {
    late AppDatabase database;
    late DriftSystemAccountResolver systemAccounts;
    late DriftAccountRepository accountRepository;
    late TransactionService transactionService;
    late TransactionQueryService queryService;
    late AccountServiceImpl accountService;

    setUp(() {
      database = createTestDatabase();
      systemAccounts = DriftSystemAccountResolver(database);
      accountRepository = DriftAccountRepository(
        database,
        systemAccounts: systemAccounts,
      );
      transactionService = TransactionServiceImpl(
        PosterImpl(DriftPostingRepository(database)),
        accountRepository: accountRepository,
        systemAccountResolver: systemAccounts,
      );
      queryService = TransactionQueryServiceImpl(
        DriftTransactionQueryRepository(database),
      );
      accountService = AccountServiceImpl(
        accountRepository,
        transactionRunner: DriftTransactionRunner(database),
        transactions: transactionService,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('lists transactions and returns details with entries', () async {
      final categoryService = CategoryServiceImpl(accountRepository);
      final wallet =
          (await accountService.createAccount(
                    const CreateAccountCommand(
                      name: '钱包',
                      type: AccountType.asset,
                      openingBalance: Money(minorUnits: 10000),
                    ),
                  )
                  as Success)
              .value;
      final food =
          (await categoryService.createCategory(
                    const CreateCategoryCommand(
                      name: '餐饮',
                      type: AccountType.expense,
                    ),
                  )
                  as Success)
              .value;

      final posted = await transactionService.createExpense(
        CreateExpenseCommand(
          amount: const Money(minorUnits: 2000),
          paidFromAccountId: wallet.id,
          expenseAccountId: food.id,
          occurredAt: DateTime(2026, 5, 8),
          counterpartyName: '咖啡店',
        ),
      );
      expect(posted, isA<Success>());

      final items =
          await queryService
              .watchTransactions(const TransactionListQuery())
              .first;
      final expenseItem = items.singleWhere(
        (item) => item.businessPurpose == BusinessPurpose.dailyExpense,
      );
      expect(expenseItem.counterpartyName, '咖啡店');
      expect(expenseItem.accountNames, contains('钱包'));
      expect(expenseItem.accountNames, contains('餐饮'));
      expect(expenseItem.categoryName, '餐饮');
      expect(expenseItem.flowOutAccountName, '钱包');
      expect(expenseItem.flowInAccountName, isNull);

      final detail =
          await queryService.watchTransactionDetail(expenseItem.id).first;
      expect(detail, isNotNull);
      expect(detail!.details.single.type, TransactionDetailType.primaryExpense);
      expect(detail.entries, hasLength(2));
      expect(
        detail.entries.map((entry) => entry.accountName),
        containsAll(['钱包', '餐饮']),
      );
    });

    test('filters account ledger by entry account', () async {
      final categoryService = CategoryServiceImpl(accountRepository);
      final wallet =
          (await accountService.createAccount(
                    const CreateAccountCommand(
                      name: '钱包',
                      type: AccountType.asset,
                    ),
                  )
                  as Success)
              .value;
      final bank =
          (await accountService.createAccount(
                    const CreateAccountCommand(
                      name: '银行卡',
                      type: AccountType.asset,
                    ),
                  )
                  as Success)
              .value;
      final food =
          (await categoryService.createCategory(
                    const CreateCategoryCommand(
                      name: '餐饮',
                      type: AccountType.expense,
                    ),
                  )
                  as Success)
              .value;

      await transactionService.createExpense(
        CreateExpenseCommand(
          amount: const Money(minorUnits: 2000),
          paidFromAccountId: wallet.id,
          expenseAccountId: food.id,
          occurredAt: DateTime(2026, 5, 8),
        ),
      );
      await transactionService.createTransfer(
        CreateTransferCommand(
          amount: const Money(minorUnits: 1000),
          fromAccountId: bank.id,
          toAccountId: wallet.id,
          occurredAt: DateTime(2026, 5, 9),
        ),
      );

      final walletLedger =
          await queryService
              .watchTransactions(TransactionListQuery(accountId: wallet.id))
              .first;

      expect(walletLedger, hasLength(2));
      expect(walletLedger.map((item) => item.businessPurpose), [
        BusinessPurpose.transfer,
        BusinessPurpose.dailyExpense,
      ]);
      final transferItem = walletLedger.first;
      expect(transferItem.flowOutAccountName, '银行卡');
      expect(transferItem.flowInAccountName, '钱包');
      expect(transferItem.accountBalanceDelta?.minorUnits, 1000);
      expect(walletLedger.last.accountBalanceDelta?.minorUnits, -2000);
    });
  });
}
