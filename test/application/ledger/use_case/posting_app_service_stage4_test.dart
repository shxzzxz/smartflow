import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/result/result.dart';
import 'package:smartflow/data/app_database.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_account_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_balance_aggregate_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_entry_read_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_posting_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_system_account_resolver.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_transaction_detail_read_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_transaction_read_repository.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/application/ledger/ledger_api.dart';

import '../../../helper/test_app_database.dart';

void main() {
  group('PostingAppService stage 4', () {
    late AppDatabase database;
    late PostingAppService service;
    late TransactionQueryService queryService;
    late AccountService accountService;
    late CategoryService categoryService;

    setUp(() {
      database = createTestDatabase();
      final systemAccounts = DriftSystemAccountResolver(database);
      final accountRepository = DriftAccountRepository(database);
      queryService = TransactionQueryServiceImpl(
        transactionRead: DriftTransactionReadRepository(database),
        entryRead: DriftEntryReadRepository(database),
        detailRead: DriftTransactionDetailReadRepository(database),
        balanceAggregate: DriftBalanceAggregateRepository(database),
      );
      final postingRepository = DriftPostingRepository(database);
      service = PostingAppServiceImpl(
        accountRepository: accountRepository,
        transactionQueryService: queryService,
        postingRepository: postingRepository,
        systemAccountResolver: systemAccounts,
        transactionRunner: DriftTransactionRunner(database),
      );
      accountService = AccountServiceImpl(
        accountRepository,
        transactionRunner: DriftTransactionRunner(database),
        transactions: service,
      );
      categoryService = CategoryServiceImpl(accountRepository);
    });

    tearDown(() async {
      await database.close();
    });

    test('corrects an expense through reversal and replacement', () async {
      final wallet = await _createAsset(accountService, '钱包');
      final food = await _createCategory(
        categoryService,
        '餐饮',
        AccountType.expense,
      );
      final shopping = await _createCategory(
        categoryService,
        '购物',
        AccountType.expense,
      );
      final original =
          (await service.createExpense(
                    CreateExpenseCommand(
                      amount: const Money(minorUnits: 1000),
                      paidFromAccountId: wallet.id,
                      expenseAccountId: food.id,
                      occurredAt: DateTime(2026, 5, 1),
                    ),
                  )
                  as Success<CreatedTransactionResult>)
              .value;

      final corrected = await service.correctExpense(
        CorrectExpenseCommand(
          transactionId: original.transactionId,
          amount: const Money(minorUnits: 1500),
          paidFromAccountId: wallet.id,
          expenseAccountId: shopping.id,
          occurredAt: DateTime(2026, 5, 2),
        ),
      );
      expect(corrected, isA<Success<CreatedTransactionResult>>());

      expect(await _balance(database, wallet.id), -1500);
      expect(await _balance(database, food.id), 0);
      expect(await _balance(database, shopping.id), 1500);

      final list =
          await queryService
              .watchTransactions(const TransactionListQuery())
              .first;
      expect(list, hasLength(1));
      expect(list.single.id, isNot(original.transactionId));
      expect(list.single.primaryAmount.minorUnits, 1500);

      final originalDetail =
          await queryService
              .watchTransactionDetail(original.transactionId)
              .first;
      expect(originalDetail!.transaction.businessState, BusinessState.replaced);
      expect(originalDetail.history, hasLength(2));
    });

    test('deletes an expense by canceling and reversing it', () async {
      final wallet = await _createAsset(accountService, '钱包');
      final food = await _createCategory(
        categoryService,
        '餐饮',
        AccountType.expense,
      );
      final original =
          (await service.createExpense(
                    CreateExpenseCommand(
                      amount: const Money(minorUnits: 1000),
                      paidFromAccountId: wallet.id,
                      expenseAccountId: food.id,
                      occurredAt: DateTime(2026, 5, 1),
                    ),
                  )
                  as Success<CreatedTransactionResult>)
              .value;

      final deleted = await service.deleteTransaction(
        DeleteTransactionCommand(transactionId: original.transactionId),
      );
      expect(deleted, isA<Success<void>>());

      expect(await _balance(database, wallet.id), 0);
      expect(await _balance(database, food.id), 0);

      final list =
          await queryService
              .watchTransactions(const TransactionListQuery())
              .first;
      expect(list, isEmpty);

      final originalDetail =
          await queryService
              .watchTransactionDetail(original.transactionId)
              .first;
      expect(originalDetail!.transaction.businessState, BusinessState.canceled);
      expect(
        originalDetail.history.single.businessPurpose,
        BusinessPurpose.dailyExpense,
      );
    });

    test(
      'corrects a refund and keeps refundable limit relative to original',
      () async {
        final wallet = await _createAsset(accountService, '钱包');
        final food = await _createCategory(
          categoryService,
          '餐饮',
          AccountType.expense,
        );
        final expense =
            (await service.createExpense(
                      CreateExpenseCommand(
                        amount: const Money(minorUnits: 1000),
                        paidFromAccountId: wallet.id,
                        expenseAccountId: food.id,
                        occurredAt: DateTime(2026, 5, 1),
                      ),
                    )
                    as Success<CreatedTransactionResult>)
                .value;
        final refund =
            (await service.createRefund(
                      CreateRefundCommand(
                        amount: const Money(minorUnits: 300),
                        parentTransactionId: expense.transactionId,
                        refundToAccountId: wallet.id,
                        occurredAt: DateTime(2026, 5, 2),
                      ),
                    )
                    as Success<CreatedTransactionResult>)
                .value;

        final corrected = await service.correctRefund(
          CorrectRefundCommand(
            transactionId: refund.transactionId,
            amount: const Money(minorUnits: 500),
            refundToAccountId: wallet.id,
            occurredAt: DateTime(2026, 5, 3),
          ),
        );

        expect(corrected, isA<Success<CreatedTransactionResult>>());
        expect(await _balance(database, wallet.id), -500);
        expect(await _balance(database, food.id), 500);
      },
    );

    test(
      'corrects a reimbursement receipt and reuses its own outstanding',
      () async {
        final wallet = await _createAsset(accountService, '钱包');
        final receivable = await _createReimbursementAccount(
          accountService,
          '报销',
        );
        final travel = await _createCategory(
          categoryService,
          '差旅',
          AccountType.expense,
        );
        final advance =
            (await service.createReimbursementAdvance(
                      CreateReimbursementAdvanceCommand(
                        amount: const Money(minorUnits: 1000),
                        receivableAccountId: receivable.id,
                        paidFromAccountId: wallet.id,
                        expenseCategoryId: travel.id,
                        occurredAt: DateTime(2026, 5, 1),
                      ),
                    )
                    as Success<CreatedTransactionResult>)
                .value;
        final receipt =
            (await service.createReimbursementReceipt(
                      CreateReimbursementReceiptCommand(
                        amount: const Money(minorUnits: 300),
                        advanceTransactionId: advance.transactionId,
                        receivableAccountId: receivable.id,
                        receiveAccountId: wallet.id,
                        occurredAt: DateTime(2026, 5, 2),
                      ),
                    )
                    as Success<CreatedTransactionResult>)
                .value;

        final corrected = await service.correctReimbursementReceipt(
          CorrectReimbursementReceiptCommand(
            transactionId: receipt.transactionId,
            amount: const Money(minorUnits: 500),
            receivableAccountId: receivable.id,
            receiveAccountId: wallet.id,
            occurredAt: DateTime(2026, 5, 3),
          ),
        );

        expect(corrected, isA<Success<CreatedTransactionResult>>());
        expect(await _balance(database, wallet.id), -500);
        expect(await _balance(database, receivable.id), 500);
      },
    );

    test(
      'corrects a reimbursement close without treating itself as blocked',
      () async {
        final wallet = await _createAsset(accountService, '钱包');
        final receivable = await _createReimbursementAccount(
          accountService,
          '报销',
        );
        final travel = await _createCategory(
          categoryService,
          '差旅',
          AccountType.expense,
        );
        final advance =
            (await service.createReimbursementAdvance(
                      CreateReimbursementAdvanceCommand(
                        amount: const Money(minorUnits: 1000),
                        receivableAccountId: receivable.id,
                        paidFromAccountId: wallet.id,
                        expenseCategoryId: travel.id,
                        occurredAt: DateTime(2026, 5, 1),
                      ),
                    )
                    as Success<CreatedTransactionResult>)
                .value;
        await service.createReimbursementReceipt(
          CreateReimbursementReceiptCommand(
            amount: const Money(minorUnits: 300),
            advanceTransactionId: advance.transactionId,
            receivableAccountId: receivable.id,
            receiveAccountId: wallet.id,
            occurredAt: DateTime(2026, 5, 2),
          ),
        );
        final close =
            (await service.closeReimbursement(
                      CloseReimbursementCommand(
                        actualReceivedAmount: const Money(minorUnits: 600),
                        advanceTransactionId: advance.transactionId,
                        receivableAccountId: receivable.id,
                        receiveAccountId: wallet.id,
                        occurredAt: DateTime(2026, 5, 3),
                      ),
                    )
                    as Success<CreatedTransactionResult>)
                .value;

        final corrected = await service.correctReimbursementClose(
          CorrectReimbursementCloseCommand(
            transactionId: close.transactionId,
            actualReceivedAmount: const Money(minorUnits: 800),
            receivableAccountId: receivable.id,
            receiveAccountId: wallet.id,
            occurredAt: DateTime(2026, 5, 4),
          ),
        );

        expect(corrected, isA<Success<CreatedTransactionResult>>());
        expect(await _balance(database, wallet.id), 100);
        expect(await _balance(database, receivable.id), 0);
        expect(await _balance(database, travel.id), 0);
      },
    );
  });
}

Future<dynamic> _createAsset(AccountService service, String name) async {
  final result = await service.createAccount(
    CreateAccountCommand(name: name, type: AccountType.asset),
  );
  return (result as Success).value;
}

Future<dynamic> _createCategory(
  CategoryService service,
  String name,
  AccountType type,
) async {
  final result = await service.createCategory(
    CreateCategoryCommand(name: name, type: type),
  );
  return (result as Success).value;
}

Future<dynamic> _createReimbursementAccount(
  AccountService service,
  String name,
) async {
  final result = await service.createAccount(
    CreateAccountCommand(
      name: name,
      type: AccountType.asset,
      subtype: AccountSubtype.reimbursement,
    ),
  );
  return (result as Success).value;
}

Future<int> _balance(AppDatabase database, int accountId) async {
  final row =
      await (database.select(database.accounts)
        ..where((account) => account.id.equals(accountId))).getSingle();
  return row.balanceMinor;
}
