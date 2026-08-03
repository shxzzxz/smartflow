import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/domain/ledger/service/account/account_role_policy.dart';
import 'package:smartflow/domain/ledger/service/posting/account_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/ledger_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_bill_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_bill_generation_suppression_repository.dart';
import 'package:smartflow/infrastructure/credit/adapter/ledger_credit_ledger_port.dart';
import 'package:smartflow/infrastructure/credit/adapter/ledger_credit_account_port.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_credit_account_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_credit_bill_source_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_repayment_repository.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_account_query_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_account_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_ledger_metrics_source.dart';
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
        expect(bills, hasLength(1));
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
              allocated: RepaymentAmountDto(
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

        await fixture.generation.generateDueBills(now: DateTime(2026, 6, 4));
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
                allocated: RepaymentAmountDto(
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

        await fixture.generation.generateDueBills(now: DateTime(2026, 6, 4));
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
        await fixture.generation.generateDueBills(now: DateTime(2026, 6, 4));
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
                    allocated: RepaymentAmountDto(
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
        await fixture.installmentRepository.saveAggregate(
          (await fixture.installmentRepository.findContract(contractId))!,
          [
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
          ],
        );
        final aggregateSchedules = await fixture.installmentRepository
            .listSchedules(contractId);
        aggregateSchedules
            .singleWhere((schedule) => schedule.periodNo == 2)
            .skip();
        await fixture.installmentRepository.saveAggregate(
          (await fixture.installmentRepository.findContract(contractId))!,
          aggregateSchedules,
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

    test(
      'due bill generation does not settle an interest-only schedule',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        final aggregate = await fixture.createInterestOnlyInstallment(
          repaymentDate: DateTime(2026, 7, 1),
        );

        await fixture.generation.generateDueBills(now: DateTime(2026, 7, 15));

        expect(
          (await fixture.installmentRepository.findSchedule(
            aggregate.schedule.id,
          ))!.status,
          InstallmentScheduleStatus.pending,
        );
      },
    );

    test(
      'manual bill generation does not settle an interest-only schedule',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        final aggregate = await fixture.createInterestOnlyInstallment(
          repaymentDate: DateTime(2026, 6, 1),
        );

        await fixture.generation.generateBillForPeriod(
          accountId: aggregate.account.id,
          period: BillPeriod.fromInt(202606),
          now: DateTime(2026, 7, 15),
        );

        expect(
          (await fixture.installmentRepository.findSchedule(
            aggregate.schedule.id,
          ))!.status,
          InstallmentScheduleStatus.pending,
        );
      },
    );

    test(
      'displayed bill refresh does not settle an interest-only schedule',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        final aggregate = await fixture.createInterestOnlyInstallment(
          repaymentDate: DateTime(2026, 7, 1),
        );
        await fixture.generation.generateDueBills(now: DateTime(2026, 7, 15));
        final schedules = await fixture.installmentRepository.listSchedules(
          aggregate.contract.id,
        );
        schedules.first.markPending();
        await fixture.installmentRepository.saveAggregate(
          aggregate.contract,
          schedules,
        );

        await fixture.generation.refreshDisplayedBillsForAccount(
          accountId: aggregate.account.id,
          now: DateTime(2026, 7, 15),
        );

        expect(
          (await fixture.installmentRepository.findSchedule(
            aggregate.schedule.id,
          ))!.status,
          InstallmentScheduleStatus.pending,
        );
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
      await fixture.installmentRepository.saveAggregate(
        (await fixture.installmentRepository.findContract(contractId))!,
        [
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
        ],
      );
      final schedule =
          (await fixture.installmentRepository.listSchedules(
            contractId,
          )).single;

      await fixture.generation.generateDueBills(now: DateTime(2026, 7, 15));
      final july = (await fixture.billRepository.listBillsByAccount(
        account.id,
      )).singleWhere((bill) => bill.period == BillPeriod.fromInt(202607));
      final originalItemId = july.items.single.id;

      final contract = await fixture.installmentRepository.findContract(
        schedule.contractId,
      );
      final schedules = await fixture.installmentRepository.listSchedules(
        schedule.contractId,
      );
      schedules
          .singleWhere((candidate) => candidate.id == schedule.id)
          .reviseExpectation(expectedRepaymentDate: DateTime(2026, 8, 1));
      await fixture.installmentRepository.saveAggregate(contract!, schedules);

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

    test('bill refresh does not drive installment aggregate status', () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      final account = await fixture.createLoanAccount();
      final contract = InstallmentContract(
        id: fixture.ids.newId(),
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
      );
      final schedule = InstallmentSchedule(
        id: fixture.ids.newId(),
        contractId: contract.id,
        periodNo: 1,
        expectedRepaymentDate: DateTime(2026, 7, 1),
        expectedPrincipal: const Money(minorUnits: 60000),
        expectedInterest: Money.zero(),
        expectedFee: Money.zero(),
        status: InstallmentScheduleStatus.pending,
        createdAt: DateTime(2026, 6, 1),
      );
      await fixture.installmentRepository.insertAggregate(contract, [schedule]);
      await fixture.generation.generateDueBills(now: DateTime(2026, 7, 15));
      final bill =
          (await fixture.billRepository.listBillsByAccount(account.id)).single;
      final billItem = bill.items.single;
      final repaymentId = fixture.ids.newId();
      final repayment = Repayment(
        id: repaymentId,
        repaymentType: RepaymentType.bill,
        targetType: RepaymentTargetType.bill,
        targetId: bill.id,
        items: [
          RepaymentItem(
            id: fixture.ids.newId(),
            repaymentId: repaymentId,
            billItemId: billItem.id,
            allocated: const RepaymentAmountBreakdown(
              principal: Money(minorUnits: 60000),
              interest: Money(minorUnits: 0),
              fee: Money(minorUnits: 0),
              discount: Money(minorUnits: 0),
            ),
          ),
        ],
      );
      await fixture.repaymentRepository.saveRepayment(repayment);

      await fixture.generation.refreshBill(bill.id);

      expect(
        (await fixture.installmentRepository.findSchedule(schedule.id))!.status,
        InstallmentScheduleStatus.pending,
      );
      expect(
        (await fixture.installmentRepository.findContract(contract.id))!.status,
        InstallmentContractStatus.active,
      );

      final schedules = await fixture.installmentRepository.listSchedules(
        contract.id,
      );
      schedules.single.markPaid();
      final persistedContract =
          (await fixture.installmentRepository.findContract(contract.id))!;
      persistedContract.refreshStatusFromSchedules(schedules);
      await fixture.installmentRepository.saveAggregate(
        persistedContract,
        schedules,
      );
      await fixture.repaymentRepository.deleteRepayment(repayment.id);
      await fixture.generation.refreshBill(bill.id);

      expect(
        (await fixture.installmentRepository.findSchedule(schedule.id))!.status,
        InstallmentScheduleStatus.paid,
      );
      expect(
        (await fixture.installmentRepository.findContract(contract.id))!.status,
        InstallmentContractStatus.settled,
      );
    });

    test('deletes a credit bill without repayment records', () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      final account = await fixture.createCreditAccount();
      await fixture.generation.generateDueBills(now: DateTime(2026, 6, 4));

      final bills = await fixture.billRepository.listBillsByAccount(account.id);
      final june = bills.singleWhere(
        (bill) => bill.period == BillPeriod.fromInt(202606),
      );
      await fixture.generation.deleteBill(june.id);
      await fixture.generation.generateDueBills(now: DateTime(2026, 6, 4));

      expect(await fixture.billRepository.findBill(june.id), isNull);
      final remaining = await fixture.billRepository.listBillsByAccount(
        account.id,
      );
      expect(remaining.any((bill) => bill.id == june.id), isFalse);
      expect(
        await fixture.billRepository.findByAccountAndPeriod(
          account.id,
          BillPeriod.fromInt(202606),
        ),
        isNull,
      );
    });

    test(
      'updates credit bill window and refreshes consumption projection',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        final account = await fixture.createCreditAccount();
        await fixture.createExpenseCategory();
        await fixture.postExpense(
          accountId: account.id,
          amount: const Money(minorUnits: 10000),
          occurredAt: DateTime(2026, 6, 15),
        );
        await fixture.generation.generateDueBills(now: DateTime(2026, 6, 4));
        final june = (await fixture.billRepository.listBillsByAccount(
          account.id,
        )).singleWhere((bill) => bill.period == BillPeriod.fromInt(202606));
        final originalRepayment = june.window!.repaymentDate;

        await fixture.generation.updateBillWindow(
          billId: june.id,
          startDate: DateTime(2026, 6, 10),
          billingDate: DateTime(2026, 6, 20),
        );

        final updated = (await fixture.billRepository.findBill(june.id))!;
        expect(updated.window!.startDate, DateTime(2026, 6, 10));
        expect(updated.window!.billingDate, DateTime(2026, 6, 20));
        expect(updated.window!.repaymentDate, originalRepayment);
        expect(
          updated.items.single.expectedPrincipal,
          const Money(minorUnits: 10000),
        );
      },
    );
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
      ledger: LedgerCreditAccountPort(accountAppService),
      creditAccounts: creditAccountRepository,
      transactionRunner: runner,
      idGenerator: ids,
    );
    postingAppService = TransactionPostingAppServiceImpl(
      accountRepository: accountRepository,
      transactionGroupRepository: postingRepository,
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
      suppressions: DriftBillGenerationSuppressionRepository(database),
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
    transactionGroupRepository: postingRepository,
    accountRepository: accountRepository,
  );
  late final TransactionEditAppService editAppService =
      TransactionEditAppServiceImpl(
        accountRepository: accountRepository,
        transactionGroupRepository: postingRepository,
        systemAccountResolver: DriftSystemAccountResolver(database),
        ledgerWriter: ledgerWriter,
        idGenerator: ids,
      );
  late final TransactionUpdateAppService updateAppService =
      TransactionUpdateAppServiceImpl(
        transactionRepository: postingRepository,
        transactionGroupRepository: postingRepository,
        ledgerWriter: ledgerWriter,
      );
  late final LedgerCreditLedgerPort creditLedgerPort = LedgerCreditLedgerPort(
    accountQueryService: accountQueryService,
    postingService: postingAppService,
    editService: editAppService,
    updateService: updateAppService,
    transactionQueryService: transactionQueryService,
  );
  late final TransactionQueryService transactionQueryService =
      TransactionQueryServiceImpl(
        transactionRead: DriftTransactionReadRepository(database),
        entryRead: DriftEntryReadRepository(database),
        detailRead: DriftTransactionDetailReadRepository(database),
        metricsSource: DriftLedgerMetricsSource(database),
      );
  late final CreditAccountAppService creditAccountAppService;
  late final TransactionPostingAppService postingAppService;
  late final CreditBillGenerationAppService generation;
  late final RepaymentAppService repaymentAppService;

  Future<CreditLedgerAccountSnapshot> createCreditAccount() {
    return creditAccountAppService.createAccount(
      CreateCreditLiabilityAccountCommand(
        name: 'Huabei',
        kind: CreditLiabilityAccountKind.credit,
        billingDay: 5,
        repaymentDay: 25,
      ),
    );
  }

  Future<CreditLedgerAccountSnapshot> createLoanAccount() {
    return creditAccountAppService.createAccount(
      const CreateCreditLiabilityAccountCommand(
        name: 'Jiebei',
        kind: CreditLiabilityAccountKind.loan,
      ),
    );
  }

  Future<
    ({
      CreditLedgerAccountSnapshot account,
      InstallmentContract contract,
      InstallmentSchedule schedule,
    })
  >
  createInterestOnlyInstallment({required DateTime repaymentDate}) async {
    final account = await createLoanAccount();
    final contract = InstallmentContract(
      id: ids.newId(),
      liabilityAccountId: account.id,
      sourceType: InstallmentSourceType.disbursement,
      disbursementAccountId: 'asset-account',
      disbursementTransactionId: 'tx-borrowing',
      principal: const Money(minorUnits: 60000),
      totalPeriods: 2,
      borrowingDate: DateTime(2026, 5, 1),
      firstRepaymentDate: repaymentDate,
      lastRepaymentDate: DateTime(
        repaymentDate.year,
        repaymentDate.month + 1,
        repaymentDate.day,
      ),
      repaymentMethod: InstallmentRepaymentMethod.interestFirst,
      interestAccrualMethod: InterestAccrualMethod.daily,
      totalFeeMinor: 0,
      status: InstallmentContractStatus.active,
      createdAt: DateTime(2026, 5, 1),
    );
    final schedule = InstallmentSchedule(
      id: ids.newId(),
      contractId: contract.id,
      periodNo: 1,
      expectedRepaymentDate: repaymentDate,
      expectedPrincipal: Money.zero(),
      expectedInterest: const Money(minorUnits: 1000),
      expectedFee: Money.zero(),
      status: InstallmentScheduleStatus.pending,
      createdAt: DateTime(2026, 5, 1),
    );
    await installmentRepository.insertAggregate(contract, [
      schedule,
      InstallmentSchedule(
        id: ids.newId(),
        contractId: contract.id,
        periodNo: 2,
        expectedRepaymentDate: contract.lastRepaymentDate,
        expectedPrincipal: contract.principal,
        expectedInterest: const Money(minorUnits: 1000),
        expectedFee: Money.zero(),
        status: InstallmentScheduleStatus.pending,
        createdAt: DateTime(2026, 5, 1),
      ),
    ]);
    return (account: account, contract: contract, schedule: schedule);
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
