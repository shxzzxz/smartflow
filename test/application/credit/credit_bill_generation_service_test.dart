import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/ledger/service/account/account_role_policy.dart';
import 'package:smartflow/domain/ledger/service/posting/account_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/ledger_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_bill_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_credit_account_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_credit_bill_source_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_repository.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_account_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_posting_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_system_account_resolver.dart';

import '../../helper/sequential_id_generator.dart';
import '../../helper/test_app_database.dart';

void main() {
  group('CreditBillGenerationService', () {
    test(
      'keeps credit bill open and refreshes consumption before billing',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        final account = await fixture.createCreditAccount();
        await fixture.createExpenseCategory();
        final expense = await fixture.postExpense(
          accountId: account.id,
          amount: const Money(minorUnits: 10000),
          occurredAt: DateTime(2026, 6, 1),
        );
        await fixture.postRefund(
          accountId: account.id,
          parentTransactionId: expense.transactionId,
          amount: const Money(minorUnits: 3000),
          occurredAt: DateTime(2026, 6, 2),
        );

        await fixture.generation.generateDueBills(now: DateTime(2026, 6, 4));

        var bills = await fixture.billRepository.listBillsByAccount(account.id);
        expect(bills, hasLength(1));
        expect(bills.single.period, BillPeriod.fromInt(202606));
        expect(bills.single.status, BillStatus.open);
        expect(
          bills.single.items.single.expectedPrincipal,
          const Money(minorUnits: 7000),
        );

        await fixture.postExpense(
          accountId: account.id,
          amount: const Money(minorUnits: 2000),
          occurredAt: DateTime(2026, 6, 3),
        );
        await fixture.generation.generateDueBills(now: DateTime(2026, 6, 4));
        bills = await fixture.billRepository.listBillsByAccount(account.id);
        expect(
          bills.single.items.single.expectedPrincipal,
          const Money(minorUnits: 9000),
        );
      },
    );

    test(
      'freezes credit bill on billing day and opens the next period',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        final account = await fixture.createCreditAccount();
        await fixture.createExpenseCategory();
        await fixture.postExpense(
          accountId: account.id,
          amount: const Money(minorUnits: 5000),
          occurredAt: DateTime(2026, 6, 1),
        );

        await fixture.generation.generateDueBills(now: DateTime(2026, 6, 5));
        await fixture.generation.generateDueBills(now: DateTime(2026, 6, 5));

        final bills = await fixture.billRepository.listBillsByAccount(
          account.id,
        );
        expect(bills.map((bill) => bill.period).toSet(), {
          BillPeriod.fromInt(202606),
          BillPeriod.fromInt(202607),
        });
        final june = bills.singleWhere(
          (bill) => bill.period == BillPeriod.fromInt(202606),
        );
        final july = bills.singleWhere(
          (bill) => bill.period == BillPeriod.fromInt(202607),
        );
        expect(june.status, BillStatus.billed);
        expect(
          june.items.single.expectedPrincipal,
          const Money(minorUnits: 5000),
        );
        expect(july.status, BillStatus.open);
      },
    );

    test('excludes borrowing transactions from credit consumption', () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      final account = await fixture.createCreditAccount();
      await fixture.accountRepository.create(
        Account(
          id: 'asset-cash',
          name: 'Cash',
          type: AccountType.asset,
          balance: Money.zero(),
          source: AccountSource.user,
        ),
      );
      await fixture.postingAppService.createBorrowing(
        CreateBorrowingCommand(
          amount: const Money(minorUnits: 50000),
          liabilityAccountId: account.id,
          receiveAccountId: 'asset-cash',
          occurredAt: DateTime(2026, 6, 1),
        ),
      );

      await fixture.generation.generateDueBills(now: DateTime(2026, 6, 4));

      final bills = await fixture.billRepository.listBillsByAccount(account.id);
      expect(bills.single.items.single.itemType, BillItemType.consumption);
      expect(bills.single.items.single.expectedPrincipal, Money.zero());
      expect(bills.single.items.single.status, BillItemStatus.paid);
    });

    test('groups loan schedules by month and skips empty months', () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      final account = await fixture.createLoanAccount();
      final contractId = await fixture.installmentRepository.insertContract(
        InstallmentContractDraft(
          liabilityAccountId: account.id,
          sourceType: InstallmentSourceType.disbursement,
          disbursementAccountId: 'asset-account',
          disbursementTransactionId: 'tx-borrowing',
          principal: const Money(minorUnits: 120000),
          totalPeriods: 3,
          borrowingDate: DateTime(2026, 6, 1),
          firstRepaymentDate: DateTime(2026, 7, 1),
          lastRepaymentDate: DateTime(2026, 9, 1),
          repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
          interestAccrualMethod: InterestAccrualMethod.daily,
          status: InstallmentContractStatus.active,
        ),
      );
      await fixture.installmentRepository.replaceSchedules(contractId, [
        InstallmentScheduleDraft(
          periodNo: 1,
          expectedRepaymentDate: DateTime(2026, 7, 1),
          expectedPrincipal: const Money(minorUnits: 60000),
          expectedInterest: const Money(minorUnits: 1000),
          expectedFee: Money.zero(),
        ),
        InstallmentScheduleDraft(
          periodNo: 2,
          expectedRepaymentDate: DateTime(2026, 8, 1),
          expectedPrincipal: const Money(minorUnits: 0),
          expectedInterest: const Money(minorUnits: 0),
          expectedFee: Money.zero(),
        ),
        InstallmentScheduleDraft(
          periodNo: 3,
          expectedRepaymentDate: DateTime(2026, 9, 1),
          expectedPrincipal: const Money(minorUnits: 60000),
          expectedInterest: const Money(minorUnits: 500),
          expectedFee: Money.zero(),
        ),
      ]);
      final skippedSchedule = (await fixture.installmentRepository
          .listSchedules(
            contractId,
          )).singleWhere((schedule) => schedule.periodNo == 2);
      await fixture.installmentRepository.updateSchedule(
        skippedSchedule.id,
        const InstallmentSchedulePatch(
          status: InstallmentScheduleStatus.skipped,
        ),
      );

      await fixture.generation.generateDueBills(now: DateTime(2026, 8, 15));

      final bills = await fixture.billRepository.listBillsByAccount(account.id);
      expect(bills.map((bill) => bill.period).toSet(), {
        BillPeriod.fromInt(202607),
        BillPeriod.fromInt(202609),
      });
      expect(
        bills.any((bill) => bill.period == BillPeriod.fromInt(202608)),
        false,
      );
      expect(bills.every((bill) => bill.status == BillStatus.billed), true);
    });
  });
}

class _Fixture {
  _Fixture() {
    runner = DriftTransactionRunner(database);
    final postingService = LedgerPostingService(
      accountRepository: accountRepository,
      systemAccountResolver: DriftSystemAccountResolver(database),
      postingEngine: PostingEngine(idGenerator: ids),
      accountPostingService: const DefaultAccountPostingService(),
      accountRolePolicy: AccountRolePolicy(
        accountRepository: accountRepository,
      ),
    );
    final accountAppService = AccountAppServiceImpl(
      accountRepository,
      transactionRunner: runner,
      ledgerPostingService: postingService,
      transactionRepository: postingRepository,
      idGenerator: ids,
    );
    creditAccountService = CreditAccountServiceImpl(
      accountAppService: accountAppService,
      creditAccounts: creditAccountRepository,
      transactionRunner: runner,
      idGenerator: ids,
      now: () => DateTime(2026, 6, 1),
    );
    postingAppService = TransactionPostingAppServiceImpl(
      accountRepository: accountRepository,
      rootGroupRepository: postingRepository,
      systemAccountResolver: DriftSystemAccountResolver(database),
      ledgerWriter: TransactionLedgerWriter(
        transactionRunner: runner,
        transactionRepository: postingRepository,
        accountRepository: accountRepository,
      ),
      idGenerator: ids,
    );
    generation = CreditBillGenerationServiceImpl(
      creditAccounts: creditAccountRepository,
      ledgerAccounts: accountRepository,
      installments: installmentRepository,
      bills: billRepository,
      billSources: DriftCreditBillSourceRepository(database),
      transactionRunner: runner,
      idGenerator: ids,
    );
  }

  final database = createTestDatabase();
  final ids = SequentialIdGenerator(prefix: 'bill-test');
  late final TransactionRunner runner;
  late final DriftAccountRepository accountRepository = DriftAccountRepository(
    database,
  );
  late final DriftCreditAccountRepository creditAccountRepository =
      DriftCreditAccountRepository(database);
  late final DriftInstallmentRepository installmentRepository =
      DriftInstallmentRepository(database);
  late final DriftBillRepository billRepository = DriftBillRepository(database);
  late final DriftPostingRepository postingRepository = DriftPostingRepository(
    database,
  );
  late final CreditAccountService creditAccountService;
  late final TransactionPostingAppService postingAppService;
  late final CreditBillGenerationService generation;

  Future<Account> createCreditAccount() {
    return creditAccountService.createAccount(
      CreateCreditLiabilityAccountCommand(
        name: 'Huabei',
        kind: CreditLiabilityAccountKind.credit,
        billingDay: 5,
        repaymentDay: 25,
        billingStartPeriod: BillPeriod(year: 2026, month: 6),
      ),
    );
  }

  Future<Account> createLoanAccount() {
    return creditAccountService.createAccount(
      const CreateCreditLiabilityAccountCommand(
        name: 'Jiebei',
        kind: CreditLiabilityAccountKind.loan,
      ),
    );
  }

  Future<void> createExpenseCategory() {
    return accountRepository.create(
      Account(
        id: 'expense-food',
        name: 'Food',
        type: AccountType.expense,
        balance: Money.zero(),
        source: AccountSource.builtin,
      ),
    );
  }

  Future<PostedTransactionResult> postExpense({
    required String accountId,
    required Money amount,
    required DateTime occurredAt,
  }) {
    return postingAppService.createExpense(
      CreateExpenseCommand(
        amount: amount,
        paidFromAccountId: accountId,
        expenseAccountId: 'expense-food',
        occurredAt: occurredAt,
      ),
    );
  }

  Future<PostedTransactionResult> postRefund({
    required String accountId,
    required String parentTransactionId,
    required Money amount,
    required DateTime occurredAt,
  }) {
    return postingAppService.createRefund(
      CreateRefundCommand(
        amount: amount,
        parentTransactionId: parentTransactionId,
        refundToAccountId: accountId,
        occurredAt: occurredAt,
      ),
    );
  }

  Future<void> close() => database.close();
}
