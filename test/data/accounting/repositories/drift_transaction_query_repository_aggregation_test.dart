import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
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
import 'package:smartflow/domain/accounting/ledger/posting_protocol.dart';

import '../../../helpers/test_app_database.dart';

void main() {
  group('DriftTransactionQueryRepository aggregation', () {
    late AppDatabase database;
    late DriftAccountRepository accountRepository;
    late DriftSystemAccountResolver systemAccounts;
    late DriftTransactionQueryRepository queryRepository;
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
      queryRepository = DriftTransactionQueryRepository(database);
      queryService = TransactionQueryServiceImpl(queryRepository);
      service = TransactionServiceImpl(
        PosterImpl(DriftPostingRepository(database)),
        accountRepository: accountRepository,
        transactionQueryRepository: queryRepository,
        systemAccountResolver: systemAccounts,
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

    test(
      'expense list item aggregates refund total and excludes child rows',
      () async {
        final wallet =
            (await accountService.createAccount(
                      const CreateAccountCommand(
                        name: '钱包',
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
        final expense =
            (await service.createExpense(
                      CreateExpenseCommand(
                        amount: const Money(minorUnits: 5800),
                        paidFromAccountId: wallet.id,
                        expenseAccountId: food.id,
                        occurredAt: DateTime(2026, 5, 1),
                      ),
                    )
                    as Success<CreatedTransactionResult>)
                .value;
        await service.createRefund(
          CreateRefundCommand(
            amount: const Money(minorUnits: 1000),
            parentTransactionId: expense.transactionId,
            refundToAccountId: wallet.id,
            occurredAt: DateTime(2026, 5, 2),
          ),
        );

        final items =
            await queryService
                .watchTransactions(const TransactionListQuery())
                .first;

        expect(
          items.where((it) => it.businessPurpose == BusinessPurpose.refund),
          isEmpty,
          reason: '退款是子交易，不应作为独立行出现',
        );
        final main = items.singleWhere(
          (it) => it.businessPurpose == BusinessPurpose.dailyExpense,
        );
        expect(main.refundedTotal?.minorUnits, 1000);
        expect(main.refundChildCount, 1);
        expect(main.reimbursementReceivedTotal, isNull);
        expect(main.repaymentInterest, isNull);
        expect(main.repaymentFee, isNull);
      },
    );

    test('list item aggregates children by root transaction id', () async {
      final wallet =
          (await accountService.createAccount(
                    const CreateAccountCommand(
                      name: '钱包',
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
      final expense =
          (await service.createExpense(
                    CreateExpenseCommand(
                      amount: const Money(minorUnits: 5800),
                      paidFromAccountId: wallet.id,
                      expenseAccountId: food.id,
                      occurredAt: DateTime(2026, 5, 1),
                    ),
                  )
                  as Success<CreatedTransactionResult>)
              .value;
      await service.createRefund(
        CreateRefundCommand(
          amount: const Money(minorUnits: 1000),
          parentTransactionId: expense.transactionId,
          refundToAccountId: wallet.id,
          occurredAt: DateTime(2026, 5, 2),
        ),
      );

      await (database.update(database.transactions)
        ..where((t) => t.id.equals(expense.transactionId))).write(
        const TransactionsCompanion(
          businessState: Value(BusinessState.replaced),
        ),
      );
      final correctionResult = await PosterImpl(
        DriftPostingRepository(database),
      ).post(
        PostTransactionCommand(
          businessPurpose: BusinessPurpose.dailyExpense,
          rootTransactionId: expense.rootTransactionId,
          mutationKind: MutationKind.correction,
          mutationPreviousTransactionId: expense.transactionId,
          occurredAt: DateTime(2026, 5, 3),
          primaryAmount: const Money(minorUnits: 6800),
          details: const [
            PostTransactionDetailInput(
              lineNo: 1,
              type: TransactionDetailType.primaryExpense,
              amount: Money(minorUnits: 6800),
            ),
          ],
          entries: [
            PostEntryInput(
              accountId: food.id,
              direction: EntryDirection.debit,
              amount: const Money(minorUnits: 6800),
            ),
            PostEntryInput(
              accountId: wallet.id,
              direction: EntryDirection.credit,
              amount: const Money(minorUnits: 6800),
            ),
          ],
        ),
      );
      expect(correctionResult, isA<Success<PostTransactionResult>>());

      final items =
          await queryService
              .watchTransactions(const TransactionListQuery())
              .first;

      final main = items.singleWhere(
        (it) => it.businessPurpose == BusinessPurpose.dailyExpense,
      );
      expect(main.primaryAmount.minorUnits, 6800);
      expect(main.refundedTotal?.minorUnits, 1000);
      expect(main.refundChildCount, 1);
    });

    test(
      'cashflow summary is derived from income and expense entries',
      () async {
        final wallet =
            (await accountService.createAccount(
                      const CreateAccountCommand(
                        name: '钱包',
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
        final salary =
            (await categoryService.createCategory(
                      const CreateCategoryCommand(
                        name: '工资',
                        type: AccountType.income,
                      ),
                    )
                    as Success)
                .value;
        final expense =
            (await service.createExpense(
                      CreateExpenseCommand(
                        amount: const Money(minorUnits: 5800),
                        paidFromAccountId: wallet.id,
                        expenseAccountId: food.id,
                        occurredAt: DateTime(2026, 5, 1),
                      ),
                    )
                    as Success<CreatedTransactionResult>)
                .value;
        await service.createRefund(
          CreateRefundCommand(
            amount: const Money(minorUnits: 1000),
            parentTransactionId: expense.transactionId,
            refundToAccountId: wallet.id,
            occurredAt: DateTime(2026, 5, 2),
          ),
        );
        await service.createIncome(
          CreateIncomeCommand(
            amount: const Money(minorUnits: 300000),
            receiveAccountId: wallet.id,
            incomeAccountId: salary.id,
            occurredAt: DateTime(2026, 5, 3),
          ),
        );

        final summary =
            await queryService
                .watchCashflowSummary(
                  CashflowSummaryQuery(
                    occurredFrom: DateTime(2026, 5),
                    occurredUntil: DateTime(2026, 6),
                  ),
                )
                .first;

        expect(summary.income.minorUnits, 300000);
        expect(summary.expense.minorUnits, 4800);
        expect(summary.net.minorUnits, 295200);
      },
    );

    test(
      'repayment list item exposes interest fee and discount from own details',
      () async {
        final bank =
            (await accountService.createAccount(
                      const CreateAccountCommand(
                        name: '招行',
                        type: AccountType.asset,
                      ),
                    )
                    as Success)
                .value;
        final card =
            (await accountService.createAccount(
                      const CreateAccountCommand(
                        name: '信用卡',
                        type: AccountType.liability,
                      ),
                    )
                    as Success)
                .value;
        final interestCat =
            (await categoryService.createCategory(
                      const CreateCategoryCommand(
                        name: '利息',
                        type: AccountType.expense,
                      ),
                    )
                    as Success)
                .value;
        final feeCat =
            (await categoryService.createCategory(
                      const CreateCategoryCommand(
                        name: '手续费',
                        type: AccountType.expense,
                      ),
                    )
                    as Success)
                .value;

        final result = await service.createRepayment(
          CreateRepaymentCommand(
            principal: const Money(minorUnits: 50000),
            interest: const Money(minorUnits: 1500),
            fee: const Money(minorUnits: 200),
            discount: const Money(minorUnits: 300),
            liabilityAccountId: card.id,
            paidFromAccountId: bank.id,
            interestExpenseAccountId: interestCat.id,
            feeExpenseAccountId: feeCat.id,
            occurredAt: DateTime(2026, 5, 10),
          ),
        );
        expect(result, isA<Success<CreatedTransactionResult>>());

        final items =
            await queryService
                .watchTransactions(const TransactionListQuery())
                .first;
        final repayment = items.singleWhere(
          (it) => it.businessPurpose == BusinessPurpose.debtRepayment,
        );
        expect(repayment.repaymentInterest?.minorUnits, 1500);
        expect(repayment.repaymentFee?.minorUnits, 200);
        expect(repayment.repaymentDiscount?.minorUnits, 300);
      },
    );

    test(
      'reimbursement advance list item aggregates received total and gap from'
      ' close child',
      () async {
        final card =
            (await accountService.createAccount(
                      const CreateAccountCommand(
                        name: '信用卡',
                        type: AccountType.liability,
                      ),
                    )
                    as Success)
                .value;
        final bank =
            (await accountService.createAccount(
                      const CreateAccountCommand(
                        name: '招行',
                        type: AccountType.asset,
                      ),
                    )
                    as Success)
                .value;
        final receivable =
            (await accountService.createAccount(
                      const CreateAccountCommand(
                        name: '公司报销',
                        type: AccountType.asset,
                        subtype: AccountSubtype.reimbursement,
                      ),
                    )
                    as Success)
                .value;
        final electricity =
            (await categoryService.createCategory(
                      const CreateCategoryCommand(
                        name: '电费',
                        type: AccountType.expense,
                        iconKey: 'flashlight-line',
                      ),
                    )
                    as Success)
                .value;

        final advance =
            (await service.createReimbursementAdvance(
                      CreateReimbursementAdvanceCommand(
                        amount: const Money(minorUnits: 50000),
                        receivableAccountId: receivable.id,
                        paidFromAccountId: card.id,
                        expenseCategoryId: electricity.id,
                        occurredAt: DateTime(2026, 5, 1),
                      ),
                    )
                    as Success<CreatedTransactionResult>)
                .value;
        // Close with under-receive to generate a gap-expense detail on child.
        await service.closeReimbursement(
          CloseReimbursementCommand(
            actualReceivedAmount: const Money(minorUnits: 48000),
            advanceTransactionId: advance.transactionId,
            receivableAccountId: receivable.id,
            receiveAccountId: bank.id,
            occurredAt: DateTime(2026, 5, 5),
          ),
        );

        final items =
            await queryService
                .watchTransactions(const TransactionListQuery())
                .first;
        // Only the advance shows up at top level.
        expect(
          items.where(
            (it) => it.businessPurpose == BusinessPurpose.reimbursementClose,
          ),
          isEmpty,
        );
        final mainAdvance = items.singleWhere(
          (it) => it.businessPurpose == BusinessPurpose.reimbursementAdvance,
        );
        expect(mainAdvance.categoryName, '电费');
        expect(mainAdvance.categoryIconKey, 'flashlight-line');
        expect(mainAdvance.reimbursementReceivedTotal?.minorUnits, 48000);
        expect(mainAdvance.reimbursementChildCount, 1);
        expect(mainAdvance.reimbursementGapExpense?.minorUnits, 2000);
        expect(mainAdvance.reimbursementGapIncome, isNull);
      },
    );

    test('occurred range filters transactions by occurredAt', () async {
      final wallet =
          (await accountService.createAccount(
                    const CreateAccountCommand(
                      name: '钱包',
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
      await service.createExpense(
        CreateExpenseCommand(
          amount: const Money(minorUnits: 1000),
          paidFromAccountId: wallet.id,
          expenseAccountId: food.id,
          occurredAt: DateTime(2026, 4, 15),
        ),
      );
      await service.createExpense(
        CreateExpenseCommand(
          amount: const Money(minorUnits: 2000),
          paidFromAccountId: wallet.id,
          expenseAccountId: food.id,
          occurredAt: DateTime(2026, 5, 10),
        ),
      );

      final mayItems =
          await queryService
              .watchTransactions(
                TransactionListQuery(
                  occurredFrom: DateTime(2026, 5),
                  occurredUntil: DateTime(2026, 6),
                ),
              )
              .first;
      expect(
        mayItems.where(
          (it) => it.businessPurpose == BusinessPurpose.dailyExpense,
        ),
        hasLength(1),
      );
      expect(mayItems.first.primaryAmount.minorUnits, 2000);
    });
  });
}
