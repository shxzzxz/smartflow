import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/result/result.dart';
import 'package:smartflow/data/app_database.dart';
import 'package:smartflow/data/accounting/repositories/drift_account_repository.dart';
import 'package:smartflow/data/accounting/repositories/drift_balance_aggregate_repository.dart';
import 'package:smartflow/data/accounting/repositories/drift_entry_read_repository.dart';
import 'package:smartflow/data/accounting/repositories/drift_posting_repository.dart';
import 'package:smartflow/data/accounting/repositories/drift_system_account_resolver.dart';
import 'package:smartflow/data/accounting/repositories/drift_transaction_detail_read_repository.dart';
import 'package:smartflow/data/accounting/repositories/drift_transaction_read_repository.dart';
import 'package:smartflow/data/transaction/drift_transaction_runner.dart';
import 'package:smartflow/domain/accounting/accounting_api.dart';
import 'package:smartflow/domain/accounting/ledger/poster.dart';
import 'package:smartflow/domain/accounting/ledger/receipt_builder.dart';

import '../../../helpers/test_app_database.dart';

void main() {
  group('TransactionService stage 3', () {
    late AppDatabase database;
    late DriftAccountRepository accountRepository;
    late DriftSystemAccountResolver systemAccounts;
    late TransactionService service;
    late TransactionQueryService queryService;
    late AccountService accountService;
    late CategoryService categoryService;

    setUp(() {
      database = createTestDatabase();
      systemAccounts = DriftSystemAccountResolver(database);
      accountRepository = DriftAccountRepository(
        database,
        systemAccounts: systemAccounts,
      );
      queryService = TransactionQueryServiceImpl(
        transactionRead: DriftTransactionReadRepository(database),
        entryRead: DriftEntryReadRepository(database),
        detailRead: DriftTransactionDetailReadRepository(database),
        balanceAggregate: DriftBalanceAggregateRepository(database),
      );
      final postingRepository = DriftPostingRepository(database);
      service = TransactionServiceImpl(
        poster: PosterImpl(postingRepository),
        receiptBuilder: ReceiptBuilder(
          accounts: accountRepository,
          query: queryService,
          systemAccounts: systemAccounts,
        ),
        accountRepository: accountRepository,
        transactionQueryService: queryService,
        postingRepository: postingRepository,
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

    test('refund credits the original expense category', () async {
      final wallet = await _createAsset(accountService, '钱包');
      final food = await _createCategory(
        categoryService,
        '餐饮',
        AccountType.expense,
      );
      final expense =
          (await service.createExpense(
                    CreateExpenseCommand(
                      amount: const Money(minorUnits: 6800),
                      paidFromAccountId: wallet.id,
                      expenseAccountId: food.id,
                      occurredAt: DateTime(2026, 5, 1),
                    ),
                  )
                  as Success<CreatedTransactionResult>)
              .value;

      final refund = await service.createRefund(
        CreateRefundCommand(
          amount: const Money(minorUnits: 200),
          parentTransactionId: expense.transactionId,
          refundToAccountId: wallet.id,
          occurredAt: DateTime(2026, 5, 2),
        ),
      );
      expect(refund, isA<Success<CreatedTransactionResult>>());

      expect(await _balance(database, wallet.id), -6600);
      expect(await _balance(database, food.id), 6600);

      final refunded = await queryService.getRefundedTotal(
        expense.rootTransactionId,
      );
      expect(refunded.minorUnits, 200);
    });

    test('refund exceeding remaining is rejected', () async {
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

      final result = await service.createRefund(
        CreateRefundCommand(
          amount: const Money(minorUnits: 1500),
          parentTransactionId: expense.transactionId,
          refundToAccountId: wallet.id,
          occurredAt: DateTime(2026, 5, 2),
        ),
      );
      expect(result, isA<FailureResult<CreatedTransactionResult>>());
      expect(
        (result as FailureResult).failure.code,
        'refund_exceeds_remaining',
      );
    });

    test('reimbursement advance + receipt + close (over-receive)', () async {
      final card = await _createLiability(accountService, '信用卡');
      final bank = await _createAsset(accountService, '招行');
      final receivable = await _createAsset(
        accountService,
        '公司报销',
        subtype: AccountSubtype.reimbursement,
      );
      final travel = await _createCategory(
        categoryService,
        '差旅',
        AccountType.expense,
      );

      final advance =
          (await service.createReimbursementAdvance(
                    CreateReimbursementAdvanceCommand(
                      amount: const Money(minorUnits: 200000),
                      receivableAccountId: receivable.id,
                      paidFromAccountId: card.id,
                      expenseCategoryId: travel.id,
                      occurredAt: DateTime(2026, 5, 1),
                    ),
                  )
                  as Success<CreatedTransactionResult>)
              .value;

      final receipt = await service.createReimbursementReceipt(
        CreateReimbursementReceiptCommand(
          amount: const Money(minorUnits: 150000),
          advanceTransactionId: advance.transactionId,
          receivableAccountId: receivable.id,
          receiveAccountId: bank.id,
          occurredAt: DateTime(2026, 5, 5),
        ),
      );
      expect(receipt, isA<Success<CreatedTransactionResult>>());

      final summary = await queryService.getReimbursementSummary(
        advance.transactionId,
      );
      expect(summary, isNotNull);
      expect(summary!.advanceAmount.minorUnits, 200000);
      expect(summary.receivedAmount.minorUnits, 150000);
      expect(summary.outstanding.minorUnits, 50000);
      expect(summary.isClosed, isFalse);

      final close = await service.closeReimbursement(
        CloseReimbursementCommand(
          actualReceivedAmount: const Money(minorUnits: 60000),
          advanceTransactionId: advance.transactionId,
          receivableAccountId: receivable.id,
          receiveAccountId: bank.id,
          occurredAt: DateTime(2026, 5, 9),
        ),
      );
      expect(close, isA<Success<CreatedTransactionResult>>());

      expect(await _balance(database, receivable.id), 0);
      expect(await _balance(database, bank.id), 210000);

      final closed = await queryService.getReimbursementSummary(
        advance.transactionId,
      );
      expect(closed!.isClosed, isTrue);

      final gapAccountId = await systemAccounts.resolveReimbursementGapIncome();
      expect(await _balance(database, gapAccountId), 10000);
    });

    test(
      'reimbursement close with under-receive uses original expense category',
      () async {
        final card = await _createLiability(accountService, '信用卡');
        final bank = await _createAsset(accountService, '招行');
        final receivable = await _createAsset(
          accountService,
          '公司报销',
          subtype: AccountSubtype.reimbursement,
        );
        final electricity = await _createCategory(
          categoryService,
          '电费',
          AccountType.expense,
        );

        final advance =
            (await service.createReimbursementAdvance(
                      CreateReimbursementAdvanceCommand(
                        amount: const Money(minorUnits: 150000),
                        receivableAccountId: receivable.id,
                        paidFromAccountId: card.id,
                        expenseCategoryId: electricity.id,
                        occurredAt: DateTime(2026, 5, 1),
                      ),
                    )
                    as Success<CreatedTransactionResult>)
                .value;

        final close = await service.closeReimbursement(
          CloseReimbursementCommand(
            actualReceivedAmount: const Money(minorUnits: 140000),
            advanceTransactionId: advance.transactionId,
            receivableAccountId: receivable.id,
            receiveAccountId: bank.id,
            occurredAt: DateTime(2026, 5, 5),
          ),
        );
        expect(close, isA<Success<CreatedTransactionResult>>());

        expect(await _balance(database, electricity.id), 10000);
        expect(await _balance(database, bank.id), 140000);
        expect(await _balance(database, receivable.id), 0);
      },
    );

    test(
      'updates reimbursement account across current reimbursement chain',
      () async {
        final card = await _createLiability(accountService, '信用卡');
        final bank = await _createAsset(accountService, '招行');
        final oldReceivable = await _createAsset(
          accountService,
          '公司报销',
          subtype: AccountSubtype.reimbursement,
        );
        final newReceivable = await _createAsset(
          accountService,
          '项目报销',
          subtype: AccountSubtype.reimbursement,
        );
        final travel = await _createCategory(
          categoryService,
          '差旅',
          AccountType.expense,
        );

        final advance =
            (await service.createReimbursementAdvance(
                      CreateReimbursementAdvanceCommand(
                        amount: const Money(minorUnits: 200000),
                        receivableAccountId: oldReceivable.id,
                        paidFromAccountId: card.id,
                        expenseCategoryId: travel.id,
                        occurredAt: DateTime(2026, 5, 1),
                      ),
                    )
                    as Success<CreatedTransactionResult>)
                .value;
        final receipt =
            (await service.createReimbursementReceipt(
                      CreateReimbursementReceiptCommand(
                        amount: const Money(minorUnits: 50000),
                        advanceTransactionId: advance.transactionId,
                        receivableAccountId: oldReceivable.id,
                        receiveAccountId: bank.id,
                        occurredAt: DateTime(2026, 5, 2),
                      ),
                    )
                    as Success<CreatedTransactionResult>)
                .value;

        final result = await service.updateTransactionBasics(
          UpdateTransactionBasicsCommand(
            transactionId: advance.transactionId,
            occurredAt: DateTime(2026, 5, 3, 8, 30),
            reimbursementAccountId: newReceivable.id,
          ),
        );
        expect(result, isA<Success<void>>());

        expect(await _balance(database, oldReceivable.id), 0);
        expect(await _balance(database, newReceivable.id), 150000);

        final updatedAdvance =
            await queryService
                .watchTransactionDetail(advance.transactionId)
                .first;
        expect(
          updatedAdvance!.transaction.occurredAt,
          DateTime(2026, 5, 3, 8, 30),
        );
        expect(
          updatedAdvance.entries
              .where((entry) => entry.accountId == newReceivable.id)
              .single
              .direction,
          EntryDirection.debit,
        );

        final updatedReceipt =
            await queryService
                .watchTransactionDetail(receipt.transactionId)
                .first;
        expect(
          updatedReceipt!.entries
              .where((entry) => entry.accountId == newReceivable.id)
              .single
              .direction,
          EntryDirection.credit,
        );
      },
    );

    test('receipt after close is rejected', () async {
      final card = await _createLiability(accountService, '信用卡');
      final bank = await _createAsset(accountService, '招行');
      final receivable = await _createAsset(
        accountService,
        '公司报销',
        subtype: AccountSubtype.reimbursement,
      );
      final cat = await _createCategory(
        categoryService,
        '差旅',
        AccountType.expense,
      );
      final advance =
          (await service.createReimbursementAdvance(
                    CreateReimbursementAdvanceCommand(
                      amount: const Money(minorUnits: 100000),
                      receivableAccountId: receivable.id,
                      paidFromAccountId: card.id,
                      expenseCategoryId: cat.id,
                      occurredAt: DateTime(2026, 5, 1),
                    ),
                  )
                  as Success<CreatedTransactionResult>)
              .value;
      await service.closeReimbursement(
        CloseReimbursementCommand(
          actualReceivedAmount: const Money(minorUnits: 100000),
          advanceTransactionId: advance.transactionId,
          receivableAccountId: receivable.id,
          receiveAccountId: bank.id,
          occurredAt: DateTime(2026, 5, 5),
        ),
      );

      final retry = await service.createReimbursementReceipt(
        CreateReimbursementReceiptCommand(
          amount: const Money(minorUnits: 1000),
          advanceTransactionId: advance.transactionId,
          receivableAccountId: receivable.id,
          receiveAccountId: bank.id,
          occurredAt: DateTime(2026, 5, 6),
        ),
      );
      expect(retry, isA<FailureResult<CreatedTransactionResult>>());
      expect(
        (retry as FailureResult).failure.code,
        'reimbursement_already_closed',
      );
    });

    test('repayment splits principal and interest', () async {
      final bank = await _createAsset(accountService, '招行');
      final card = await _createLiability(accountService, '信用卡');
      final interest = await _createCategory(
        categoryService,
        '还款利息',
        AccountType.expense,
      );

      final result = await service.createRepayment(
        CreateRepaymentCommand(
          principal: const Money(minorUnits: 80000),
          interest: const Money(minorUnits: 3000),
          liabilityAccountId: card.id,
          paidFromAccountId: bank.id,
          interestExpenseAccountId: interest.id,
          occurredAt: DateTime(2026, 5, 10),
        ),
      );
      expect(result, isA<Success<CreatedTransactionResult>>());

      expect(await _balance(database, bank.id), -83000);
      expect(await _balance(database, card.id), -80000);
      expect(await _balance(database, interest.id), 3000);
    });

    test(
      'repayment discount reduces cash paid and uses discount income',
      () async {
        final bank = await _createAsset(accountService, '招行');
        final card = await _createLiability(accountService, '信用卡');

        final result = await service.createRepayment(
          CreateRepaymentCommand(
            principal: const Money(minorUnits: 10000),
            discount: const Money(minorUnits: 500),
            liabilityAccountId: card.id,
            paidFromAccountId: bank.id,
            occurredAt: DateTime(2026, 5, 10),
          ),
        );
        expect(result, isA<Success<CreatedTransactionResult>>());

        final discountIncomeId = await systemAccounts.resolveDiscountIncome();
        expect(await _balance(database, bank.id), -9500);
        expect(await _balance(database, card.id), -10000);
        expect(await _balance(database, discountIncomeId), 500);
      },
    );

    test(
      'borrowing without cash account uses opening balance equity',
      () async {
        final card = await _createLiability(accountService, '亲友借款');

        final result = await service.createBorrowing(
          CreateBorrowingCommand(
            amount: const Money(minorUnits: 1000000),
            liabilityAccountId: card.id,
            occurredAt: DateTime(2026, 5, 1),
          ),
        );
        expect(result, isA<Success<CreatedTransactionResult>>());

        final equityId = await systemAccounts.resolveOpeningBalance();
        expect(await _balance(database, card.id), 1000000);
        expect(await _balance(database, equityId), -1000000);
      },
    );

    test('balance adjustment computes delta and uses opening equity', () async {
      final fund = await _createAsset(
        accountService,
        '基金',
        opening: const Money(minorUnits: 1000000),
      );

      final result = await service.adjustBalance(
        AdjustBalanceCommand(
          accountId: fund.id,
          targetBalance: const Money(minorUnits: 950000),
          occurredAt: DateTime(2026, 5, 9),
        ),
      );
      expect(result, isA<Success<CreatedTransactionResult>>());

      expect(await _balance(database, fund.id), 950000);
    });

    test('list excludes child transactions by default', () async {
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
      await service.createRefund(
        CreateRefundCommand(
          amount: const Money(minorUnits: 200),
          parentTransactionId: expense.transactionId,
          refundToAccountId: wallet.id,
          occurredAt: DateTime(2026, 5, 2),
        ),
      );

      final list =
          await queryService
              .watchTransactions(const TransactionListQuery())
              .first;
      expect(
        list.where((it) => it.businessPurpose == BusinessPurpose.refund),
        isEmpty,
      );

      final detail =
          await queryService
              .watchTransactionDetail(expense.transactionId)
              .first;
      expect(detail!.children, hasLength(1));
      expect(detail.children.single.businessPurpose, BusinessPurpose.refund);
      expect(detail.refundedTotal!.minorUnits, 200);
    });
  });
}

Future<dynamic> _createAsset(
  AccountService service,
  String name, {
  Money opening = const Money(minorUnits: 0),
  AccountSubtype? subtype,
}) async {
  final result = await service.createAccount(
    CreateAccountCommand(
      name: name,
      type: AccountType.asset,
      openingBalance: opening,
      subtype: subtype,
    ),
  );
  return (result as Success).value;
}

Future<dynamic> _createLiability(AccountService service, String name) async {
  final result = await service.createAccount(
    CreateAccountCommand(name: name, type: AccountType.liability),
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

Future<int> _balance(AppDatabase database, int accountId) async {
  final row =
      await (database.select(database.accounts)
        ..where((account) => account.id.equals(accountId))).getSingle();
  return row.balanceMinor;
}
