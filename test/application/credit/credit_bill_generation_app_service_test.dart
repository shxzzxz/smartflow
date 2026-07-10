import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/ledger/service/account/account_role_policy.dart';
import 'package:smartflow/domain/ledger/service/posting/account_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/ledger_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_bill_repository.dart';
import 'package:smartflow/infrastructure/credit/adapter/ledger_credit_ledger_port.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_credit_account_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_credit_bill_source_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_repayment_repository.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_account_query_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_account_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_balance_aggregate_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_entry_read_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_posting_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_system_account_resolver.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_transaction_detail_read_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_transaction_read_repository.dart';

import '../../helper/sequential_id_generator.dart';
import '../../helper/test_app_database.dart';

void main() {
  group('CreditBillGenerationAppService', () {
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
        expect(bills, hasLength(2));
        var june = bills.singleWhere(
          (bill) => bill.period == BillPeriod.fromInt(202606),
        );
        expect(june.status, BillStatus.open);
        expect(
          june.items.single.expectedPrincipal,
          const Money(minorUnits: 7000),
        );

        await fixture.postExpense(
          accountId: account.id,
          amount: const Money(minorUnits: 2000),
          occurredAt: DateTime(2026, 6, 3),
        );
        await fixture.generation.generateDueBills(now: DateTime(2026, 6, 4));
        bills = await fixture.billRepository.listBillsByAccount(account.id);
        june = bills.singleWhere(
          (bill) => bill.period == BillPeriod.fromInt(202606),
        );
        expect(
          june.items.single.expectedPrincipal,
          const Money(minorUnits: 7000),
        );

        await fixture.generation.refreshDisplayedBillsForAccount(
          accountId: account.id,
          now: DateTime(2026, 6, 4),
        );
        june = (await fixture.billRepository.listBillsByAccount(
          account.id,
        )).singleWhere((bill) => bill.period == BillPeriod.fromInt(202606));
        expect(
          june.items.single.expectedPrincipal,
          const Money(minorUnits: 9000),
        );
      },
    );

    test('keeps open bill repayment status when bill becomes billed', () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      final account = await fixture.createCreditAccount();
      await fixture.createExpenseCategory();
      await fixture.postExpense(
        accountId: account.id,
        amount: const Money(minorUnits: 10000),
        occurredAt: DateTime(2026, 6, 1),
      );

      await fixture.generation.generateDueBills(now: DateTime(2026, 6, 4));
      final openBill = (await fixture.billRepository.listBillsByAccount(
        account.id,
      )).singleWhere((bill) => bill.period == BillPeriod.fromInt(202606));
      expect(openBill.status, BillStatus.open);
      final openItemId = openBill.items.single.id;

      await fixture.repaymentAppService.createBillRepayment(
        CreateBillRepaymentCommand(
          billId: openBill.id,
          allocations: [
            BillRepaymentAllocation(
              billItemId: openItemId,
              allocated: RepaymentAmountBreakdown(
                principal: const Money(minorUnits: 10000),
                interest: Money.zero(),
                fee: Money.zero(),
                discount: Money.zero(),
              ),
            ),
          ],
        ),
      );

      await fixture.generation.generateDueBills(now: DateTime(2026, 6, 5));

      final bills = await fixture.billRepository.listBillsByAccount(account.id);
      final june = bills.singleWhere(
        (bill) => bill.period == BillPeriod.fromInt(202606),
      );
      expect(june.status, BillStatus.settled);
      expect(june.items.single.id, openItemId);
      expect(june.items.single.status, BillItemStatus.paid);
    });

    test(
      'syncs billed credit bill after source consumption increases',
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
        final june = (await fixture.billRepository.listBillsByAccount(
          account.id,
        )).singleWhere((bill) => bill.period == BillPeriod.fromInt(202606));
        await fixture.repaymentAppService.createBillRepayment(
          CreateBillRepaymentCommand(
            billId: june.id,
            allocations: [
              BillRepaymentAllocation(
                billItemId: june.items.single.id,
                allocated: RepaymentAmountBreakdown(
                  principal: const Money(minorUnits: 5000),
                  interest: Money.zero(),
                  fee: Money.zero(),
                  discount: Money.zero(),
                ),
              ),
            ],
          ),
        );
        expect(
          (await fixture.billRepository.findBill(june.id))!.status,
          BillStatus.settled,
        );

        await fixture.postExpense(
          accountId: account.id,
          amount: const Money(minorUnits: 2000),
          occurredAt: DateTime(2026, 6, 2),
        );

        await fixture.generation.refreshBill(june.id);

        final synced = await fixture.billRepository.findBill(june.id);
        expect(
          synced!.items.single.expectedPrincipal,
          const Money(minorUnits: 7000),
        );
        expect(synced.items.single.status, BillItemStatus.partiallyPaid);
        expect(synced.status, BillStatus.billed);
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

    test(
      'places bill conversion schedules into the next credit bill',
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
        final june = (await fixture.billRepository.listBillsByAccount(
          account.id,
        )).singleWhere((bill) => bill.period == BillPeriod.fromInt(202606));

        final result = await fixture.repaymentAppService
            .createBillConversionInstallmentRepayment(
              CreateBillConversionInstallmentRepaymentCommand(
                billId: june.id,
                allocations: [
                  BillRepaymentAllocation(
                    billItemId: june.items.single.id,
                    allocated: RepaymentAmountBreakdown(
                      principal: const Money(minorUnits: 5000),
                      interest: Money.zero(),
                      fee: Money.zero(),
                      discount: Money.zero(),
                    ),
                  ),
                ],
                totalPeriods: 1,
                repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
              ),
            );

        await fixture.generation.refreshDisplayedBillsForAccount(
          accountId: account.id,
          now: DateTime(2026, 7, 4),
        );

        final july = (await fixture.billRepository.listBillsByAccount(
          account.id,
        )).singleWhere((bill) => bill.period == BillPeriod.fromInt(202607));
        final installmentItem = july.items.singleWhere(
          (item) => item.itemType == BillItemType.installment,
        );
        expect(installmentItem.contractId, result.contractId);
        expect(
          installmentItem.expectedPrincipal,
          const Money(minorUnits: 5000),
        );
        expect(installmentItem.repaymentDate, DateTime(2026, 7, 25));
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
      final june = bills.singleWhere(
        (bill) => bill.period == BillPeriod.fromInt(202606),
      );
      expect(june.items.single.itemType, BillItemType.consumption);
      expect(june.items.single.expectedPrincipal, Money.zero());
      expect(june.items.single.status, BillItemStatus.paid);
    });

    test(
      'generates only the current loan bill, including when empty',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        final account = await fixture.createLoanAccount();
        final contractId = fixture.ids.newId();
        await fixture.installmentRepository.saveContract(
          InstallmentContract(
            id: contractId,
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
            totalFeeMinor: 0,
            status: InstallmentContractStatus.active,
            createdAt: DateTime(2026, 6, 1),
          ),
        );
        await fixture.installmentRepository.replaceSchedules(contractId, [
          InstallmentSchedule(
            id: fixture.ids.newId(),
            contractId: contractId,
            periodNo: 1,
            expectedRepaymentDate: DateTime(2026, 7, 1),
            expectedPrincipal: const Money(minorUnits: 60000),
            expectedInterest: const Money(minorUnits: 1000),
            expectedFee: Money.zero(),
            status: InstallmentScheduleStatus.pending,
            createdAt: DateTime(2026, 6, 1),
          ),
          InstallmentSchedule(
            id: fixture.ids.newId(),
            contractId: contractId,
            periodNo: 2,
            expectedRepaymentDate: DateTime(2026, 8, 1),
            expectedPrincipal: const Money(minorUnits: 0),
            expectedInterest: const Money(minorUnits: 0),
            expectedFee: Money.zero(),
            status: InstallmentScheduleStatus.pending,
            createdAt: DateTime(2026, 6, 1),
          ),
          InstallmentSchedule(
            id: fixture.ids.newId(),
            contractId: contractId,
            periodNo: 3,
            expectedRepaymentDate: DateTime(2026, 9, 1),
            expectedPrincipal: const Money(minorUnits: 60000),
            expectedInterest: const Money(minorUnits: 500),
            expectedFee: Money.zero(),
            status: InstallmentScheduleStatus.pending,
            createdAt: DateTime(2026, 6, 1),
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

        final bills = await fixture.billRepository.listBillsByAccount(
          account.id,
        );
        expect(bills, hasLength(1));
        expect(bills.single.period, BillPeriod.fromInt(202608));
        expect(bills.single.items, isEmpty);
        expect(bills.single.status, BillStatus.settled);
      },
    );

    test('cross-month schedule creates a new bill item identity', () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      final account = await fixture.createLoanAccount();
      final contractId = fixture.ids.newId();
      await fixture.installmentRepository.saveContract(
        InstallmentContract(
          id: contractId,
          liabilityAccountId: account.id,
          sourceType: InstallmentSourceType.disbursement,
          disbursementAccountId: 'asset-account',
          disbursementTransactionId: 'tx-borrowing',
          principal: const Money(minorUnits: 60000),
          totalPeriods: 1,
          borrowingDate: DateTime(2026, 6, 1),
          firstRepaymentDate: DateTime(2026, 7, 1),
          lastRepaymentDate: DateTime(2026, 7, 1),
          repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
          interestAccrualMethod: InterestAccrualMethod.daily,
          totalFeeMinor: 0,
          status: InstallmentContractStatus.active,
          createdAt: DateTime(2026, 6, 1),
        ),
      );
      await fixture.installmentRepository.replaceSchedules(contractId, [
        InstallmentSchedule(
          id: fixture.ids.newId(),
          contractId: contractId,
          periodNo: 1,
          expectedRepaymentDate: DateTime(2026, 7, 1),
          expectedPrincipal: const Money(minorUnits: 60000),
          expectedInterest: Money.zero(),
          expectedFee: Money.zero(),
          status: InstallmentScheduleStatus.pending,
          createdAt: DateTime(2026, 6, 1),
        ),
      ]);
      final schedule =
          (await fixture.installmentRepository.listSchedules(
            contractId,
          )).single;

      await fixture.generation.generateDueBills(now: DateTime(2026, 7, 15));
      final july = (await fixture.billRepository.listBillsByAccount(
        account.id,
      )).singleWhere((bill) => bill.period == BillPeriod.fromInt(202607));
      final originalItemId = july.items.single.id;

      await fixture.installmentRepository.updateSchedule(
        schedule.id,
        InstallmentSchedulePatch(expectedRepaymentDate: DateTime(2026, 8, 1)),
      );

      await fixture.generation.generateDueBills(now: DateTime(2026, 8, 15));
      final august = (await fixture.billRepository.listBillsByAccount(
        account.id,
      )).singleWhere((bill) => bill.period == BillPeriod.fromInt(202608));
      expect(august.items.single.id, isNot(originalItemId));
      expect(august.items.single.scheduleId, schedule.id);

      await fixture.generation.refreshBill(july.id);

      final syncedJuly = await fixture.billRepository.findBill(july.id);
      expect(syncedJuly!.items, isEmpty);
      expect(syncedJuly.status, BillStatus.settled);
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
    creditAccountAppService = CreditAccountAppServiceImpl(
      accountAppService: accountAppService,
      creditAccounts: creditAccountRepository,
      transactionRunner: runner,
      idGenerator: ids,
    );
    postingAppService = TransactionPostingAppServiceImpl(
      accountRepository: accountRepository,
      rootGroupRepository: postingRepository,
      systemAccountResolver: DriftSystemAccountResolver(database),
      ledgerWriter: ledgerWriter,
      idGenerator: ids,
    );
    generation = CreditBillGenerationAppServiceImpl(
      creditAccounts: creditAccountRepository,
      ledger: creditLedgerPort,
      installments: installmentRepository,
      repayments: repaymentRepository,
      bills: billRepository,
      billSources: DriftCreditBillSourceRepository(database),
      transactionRunner: runner,
      idGenerator: ids,
    );
    repaymentAppService = RepaymentAppServiceImpl(
      bills: billRepository,
      repayments: repaymentRepository,
      installments: installmentRepository,
      ledger: creditLedgerPort,
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
  late final DriftRepaymentRepository repaymentRepository =
      DriftRepaymentRepository(database);
  late final DriftBillRepository billRepository = DriftBillRepository(database);
  late final AccountQueryService accountQueryService = AccountQueryServiceImpl(
    accounts: DriftAccountQueryRepository(database),
  );
  late final DriftPostingRepository postingRepository = DriftPostingRepository(
    database,
  );
  late final TransactionLedgerWriter ledgerWriter = TransactionLedgerWriter(
    transactionRunner: runner,
    transactionRepository: postingRepository,
    accountRepository: accountRepository,
  );
  late final TransactionCorrectionAppService correctionAppService =
      TransactionCorrectionAppServiceImpl(
        accountRepository: accountRepository,
        rootGroupRepository: postingRepository,
        systemAccountResolver: DriftSystemAccountResolver(database),
        ledgerWriter: ledgerWriter,
        idGenerator: ids,
      );
  late final TransactionUpdateAppService updateAppService =
      TransactionUpdateAppServiceImpl(
        transactionRepository: postingRepository,
        rootGroupRepository: postingRepository,
        ledgerWriter: ledgerWriter,
      );
  late final LedgerCreditLedgerPort creditLedgerPort = LedgerCreditLedgerPort(
    accountQueryService: accountQueryService,
    postingService: postingAppService,
    correctionService: correctionAppService,
    updateService: updateAppService,
    transactionQueryService: transactionQueryService,
  );
  late final TransactionQueryService transactionQueryService =
      TransactionQueryServiceImpl(
        transactionRead: DriftTransactionReadRepository(database),
        entryRead: DriftEntryReadRepository(database),
        detailRead: DriftTransactionDetailReadRepository(database),
        balanceAggregate: DriftBalanceAggregateRepository(database),
      );
  late final CreditAccountAppService creditAccountAppService;
  late final TransactionPostingAppService postingAppService;
  late final CreditBillGenerationAppService generation;
  late final RepaymentAppService repaymentAppService;

  Future<Account> createCreditAccount() {
    return creditAccountAppService.createAccount(
      CreateCreditLiabilityAccountCommand(
        name: 'Huabei',
        kind: CreditLiabilityAccountKind.credit,
        billingDay: 5,
        repaymentDay: 25,
      ),
    );
  }

  Future<Account> createLoanAccount() {
    return creditAccountAppService.createAccount(
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
