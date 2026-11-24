import 'package:smartflow/infrastructure/database/app_database.dart'
    show BooksCompanion;
import 'package:smartflow/infrastructure/ledger/repository/drift_book_repository.dart';
import '../../helper/fake_book_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:smartflow/domain/ledger/service/account/account_role_policy.dart';
import 'package:smartflow/domain/ledger/service/posting/account_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/ledger_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/infrastructure/credit/adapter/ledger_credit_account_port.dart';
import 'package:smartflow/infrastructure/credit/adapter/ledger_credit_ledger_port.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_bill_generation_suppression_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_bill_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_credit_account_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_credit_bill_source_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_repayment_repository.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_account_query_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_account_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_entry_read_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_ledger_metrics_source.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_posting_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_system_account_resolver.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_transaction_line_read_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_transaction_read_repository.dart';

import '../../helper/fake_counterparty_repository.dart';
import '../../helper/fake_transaction_tag_repository.dart';
import '../../helper/sequential_id_generator.dart';
import '../../helper/test_app_database.dart';

void main() {
  test(
    'expenses in two books share a bill repaid by one transaction in a third book',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      for (final id in ['book-a', 'book-b', 'book-c']) {
        await fixture.database
            .into(fixture.database.books)
            .insert(BooksCompanion.insert(id: id, name: id));
      }
      final account = await fixture.createCreditAccount();
      await fixture.createExpenseCategory();
      final first = await fixture.postExpense(
        bookId: 'book-a',
        accountId: account.id,
        amount: const Money(minorUnits: 10000),
        occurredAt: DateTime(2026, 6, 1),
      );
      final second = await fixture.postExpense(
        bookId: 'book-b',
        accountId: account.id,
        amount: const Money(minorUnits: 5000),
        occurredAt: DateTime(2026, 6, 2),
      );
      await fixture.generation.generateDueBills(now: DateTime(2026, 6, 4));
      await fixture.generation.generateDueBills(now: DateTime(2026, 6, 6));
      final bill = (await fixture.billRepository.listBillsByAccount(account.id))
          .singleWhere(
            (bill) => bill.expectedPrincipal == const Money(minorUnits: 15000),
          );
      expect(bill.expectedPrincipal, const Money(minorUnits: 15000));
      await fixture.accountRepository.create(
        Account(
          id: 'bank-book-test',
          name: 'Bank',
          type: AccountType.asset,
          subtype: AccountSubtype.fund,
          profileKey: 'ledger.fund',
          source: AccountSource.user,
          balance: const Money(minorUnits: 20000),
        ),
      );
      final repayment = await fixture.repaymentAppService.createBillRepayment(
        CreateBillRepaymentCommand(
          billId: bill.id,
          allocations: [
            for (final item in bill.items)
              BillRepaymentAllocation(
                billItemId: item.id,
                allocated: RepaymentAmountDto(
                  principal: item.expectedPrincipal,
                  interest: item.expectedInterest,
                  fee: item.expectedFee,
                  discount: Money.zero(),
                ),
              ),
          ],
          transactionInfo: RepaymentTransactionInfo(
            bookId: 'book-c',
            paidFromAccountId: 'bank-book-test',
            occurredAt: DateTime(2026, 6, 6),
          ),
        ),
      );
      expect(
        (await fixture.transactionQueryService.findTransactionById(
          first.transactionId,
        ))!.bookId,
        'book-a',
      );
      expect(
        (await fixture.transactionQueryService.findTransactionById(
          second.transactionId,
        ))!.bookId,
        'book-b',
      );
      final transaction = (await fixture.transactionQueryService
          .findTransactionById(repayment.transactionId!))!;
      expect(transaction.bookId, 'book-c');
      expect(transaction.parentTransactionId, isNull);
      expect(
        (await fixture.accountQueryService.findAccountById(
          account.id,
        ))!.balance,
        Money.zero(),
      );
      expect(
        (await fixture.billRepository.findBill(bill.id))!.hasOutstandingItems,
        isFalse,
      );
    },
  );

  group('CreditBillGenerationAppService', () {
    test('account and installment writes do not generate bills', () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      final account = await fixture.createCreditAccount();
      await fixture.createInterestOnlyInstallment(
        repaymentDate: DateTime(2026, 7, 25),
        liabilityAccount: account,
      );
      await fixture.creditAccountAppService.editAccount(
        EditCreditLiabilityAccountCommand(
          accountId: account.id,
          name: 'Huabei',
          repaymentDay: const Patch.set(26),
        ),
      );
      expect(
        await fixture.billRepository.listBillsByAccount(account.id),
        isEmpty,
      );
    });

    test(
      'daily maintenance projects all future obligations without inflating bill debt',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        final (:account, :contract, :schedule) = await fixture
            .createInterestOnlyInstallment(repaymentDate: DateTime(2026, 7, 1));
        final query = CreditAccountQueryServiceImpl(
          creditAccounts: fixture.creditAccountRepository,
          bills: fixture.billRepository,
          installments: fixture.installmentRepository,
          repayments: fixture.repaymentRepository,
          ledger: fixture.creditLedgerPort,
          now: () => fixture.today,
        );
        final before = (await query.findOverview(account.id))!;
        await Future.wait([
          fixture.generation.generateDueBills(now: fixture.today),
          fixture.generation.generateDueBills(now: fixture.today),
        ]);
        final bills = await fixture.billRepository.listBillsByAccount(
          account.id,
        );
        expect(bills.map((bill) => bill.period.toInt()), [
          202608,
          202607,
          202606,
        ]);
        expect(
          bills
              .singleWhere((bill) => bill.period.toInt() == 202607)
              .items
              .single
              .scheduleId,
          schedule.id,
        );
        expect(
          bills
              .singleWhere((bill) => bill.period.toInt() == 202608)
              .expectedPrincipal
              .minorUnits,
          60000,
        );
        final billIds = bills.map((bill) => bill.id).toList();
        final itemIds = bills
            .expand((bill) => bill.items)
            .map((item) => item.id)
            .toList();
        await fixture.generation.generateDueBills(now: fixture.today);
        final repeated = await fixture.billRepository.listBillsByAccount(
          account.id,
        );
        expect(repeated.map((bill) => bill.id).toList(), billIds);
        expect(
          repeated.expand((bill) => bill.items).map((item) => item.id).toList(),
          itemIds,
        );
        final after = (await query.findOverview(account.id))!;
        expect(after.buckets.billDebt, before.buckets.billDebt);
        expect(after.buckets.futureContractDebt.minorUnits, 60000);
        expect(
          after.buckets.futureContractDebt,
          before.buckets.futureContractDebt,
        );
        expect(after.buckets.unattributedDebt, before.buckets.unattributedDebt);
        expect(
          (await fixture.installmentRepository.findContract(
            contract.id,
          ))!.status,
          InstallmentContractStatus.active,
        );
      },
    );

    test(
      'billing day rebuild retains current range and replaces future manual ranges',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        final account = await fixture.createCreditAccount();
        await fixture.createInterestOnlyInstallment(
          repaymentDate: DateTime(2026, 7, 25),
          liabilityAccount: account,
        );
        await fixture.createExpenseCategory();
        await fixture.postExpense(
          accountId: account.id,
          amount: const Money(minorUnits: 10000),
          occurredAt: DateTime(2026, 6, 1),
        );
        await fixture.generation.generateDueBills(now: fixture.today);
        final current = (await fixture.billRepository.findByAccountAndPeriod(
          account.id,
          BillPeriod.fromInt(202606),
        ))!;
        final july = (await fixture.billRepository.findByAccountAndPeriod(
          account.id,
          BillPeriod.fromInt(202607),
        ))!;
        final julyConsumption = july.items.singleWhere(
          (item) => item.itemType == BillItemType.consumption,
        );
        await fixture.generation.updateConsumptionWindow(
          billId: july.id,
          billItemId: julyConsumption.id,
          startInclusive: DateTime(2026, 6, 10),
          endInclusive: DateTime(2026, 7, 20),
        );
        final augustBefore = (await fixture.billRepository
            .findByAccountAndPeriod(account.id, BillPeriod.fromInt(202608)))!;
        expect(
          augustBefore.items
              .singleWhere((item) => item.itemType == BillItemType.consumption)
              .startInclusive,
          DateTime(2026, 7, 5),
        );
        await fixture.generation.generateBillForPeriod(
          accountId: account.id,
          period: BillPeriod.fromInt(202609),
          now: fixture.today,
        );
        await fixture.postExpense(
          accountId: account.id,
          amount: const Money(minorUnits: 2000),
          occurredAt: DateTime(2026, 6, 2),
        );
        await fixture.creditAccountAppService.editAccount(
          EditCreditLiabilityAccountCommand(
            accountId: account.id,
            name: 'Huabei',
            billingDay: const Patch.set(15),
          ),
        );
        final retained = (await fixture.billRepository.findBill(current.id))!;
        expect(retained.items.single.id, current.items.single.id);
        expect(retained.items.single.startInclusive, DateTime(2026, 5, 5));
        expect(retained.items.single.endInclusive, DateTime(2026, 6, 4));
        expect(retained.expectedPrincipal.minorUnits, 10000);
        final rebuilt = (await fixture.billRepository.findByAccountAndPeriod(
          account.id,
          BillPeriod.fromInt(202607),
        ))!;
        expect(rebuilt.id, isNot(july.id));
        final rebuiltConsumption = rebuilt.items.singleWhere(
          (item) => item.itemType == BillItemType.consumption,
        );
        expect(rebuiltConsumption.startInclusive, DateTime(2026, 6, 5));
        expect(rebuiltConsumption.endInclusive, DateTime(2026, 7, 14));
        expect(
          rebuilt.items
              .singleWhere((item) => item.itemType == BillItemType.installment)
              .repaymentDate,
          DateTime(2026, 7, 25),
        );
        expect(
          await fixture.billRepository.findByAccountAndPeriod(
            account.id,
            BillPeriod.fromInt(202609),
          ),
          isNull,
        );
        fixture.today = DateTime(2026, 6, 10);
        await fixture.generation.generateDueBills(now: fixture.today);
        expect(
          (await fixture.billRepository.findBill(
            current.id,
          ))!.expectedPrincipal.minorUnits,
          10000,
        );
        expect(
          (await fixture.billRepository.findBill(rebuilt.id))!.items
              .singleWhere((item) => item.itemType == BillItemType.consumption)
              .startInclusive,
          DateTime(2026, 6, 5),
        );
        await fixture.generation.refreshBill(current.id);
        expect(
          (await fixture.billRepository.findBill(
            current.id,
          ))!.expectedPrincipal.minorUnits,
          12000,
        );
      },
    );

    test('billing day rebuild preserves future repayment references', () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      final account = await fixture.createCreditAccount();
      await fixture.createInterestOnlyInstallment(
        repaymentDate: DateTime(2026, 7, 25),
        liabilityAccount: account,
      );
      await fixture.generation.generateDueBills(now: fixture.today);
      final july = (await fixture.billRepository.findByAccountAndPeriod(
        account.id,
        BillPeriod.fromInt(202607),
      ))!;
      final installment = july.items.singleWhere(
        (item) => item.itemType == BillItemType.installment,
      );
      await fixture.repaymentAppService.createBillRepayment(
        CreateBillRepaymentCommand(
          billId: july.id,
          repaymentDate: fixture.today,
          allocations: [
            BillRepaymentAllocation(
              billItemId: installment.id,
              allocated: RepaymentAmountDto(
                principal: Money.zero(),
                interest: const Money(minorUnits: 1000),
                fee: Money.zero(),
                discount: Money.zero(),
              ),
            ),
          ],
        ),
      );
      await fixture.creditAccountAppService.editAccount(
        EditCreditLiabilityAccountCommand(
          accountId: account.id,
          name: 'Huabei',
          billingDay: const Patch.set(15),
        ),
      );
      final rebuilt = (await fixture.billRepository.findBill(july.id))!;
      final updatedInstallment = rebuilt.items.singleWhere(
        (item) => item.itemType == BillItemType.installment,
      );
      expect(updatedInstallment.id, installment.id);
      expect(updatedInstallment.status, BillItemStatus.paid);
      expect(
        rebuilt.items
            .singleWhere((item) => item.itemType == BillItemType.consumption)
            .endInclusive,
        DateTime(2026, 7, 14),
      );
      final repayment = (await fixture.repaymentRepository.listByTarget(
        RepaymentTargetType.bill,
        july.id,
      )).single;
      expect(repayment.items.single.billItemId, installment.id);
      expect(repayment.items.single.allocated.interest.minorUnits, 1000);
      final preview = await BillQueryServiceImpl(
        bills: fixture.billRepository,
        creditAccounts: fixture.creditAccountRepository,
        installments: fixture.installmentRepository,
        repayments: fixture.repaymentRepository,
        ledger: fixture.creditLedgerPort,
        now: () => fixture.today,
      ).listAccountBillPreview(account.id);
      expect(preview.map((bill) => bill.period.toInt()), [202606, 202607]);
    });

    test(
      'billing day rebuild rolls back account changes and deleted projections on failure',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        final account = await fixture.createCreditAccount();
        await fixture.createInterestOnlyInstallment(
          repaymentDate: DateTime(2026, 7, 25),
          liabilityAccount: account,
        );
        await fixture.generation.generateDueBills(now: fixture.today);
        final currentId = (await fixture.billRepository.findByAccountAndPeriod(
          account.id,
          BillPeriod.fromInt(202606),
        ))!.id;
        final beforeBills = await fixture.database
            .select(fixture.database.bills)
            .get();
        final beforeItems = await fixture.database
            .select(fixture.database.billItems)
            .get();
        final beforeName = (await fixture.accountRepository.findById(
          account.id,
        ))!.name;
        await fixture.database.customStatement('''
CREATE TRIGGER reject_cycle_rebuild BEFORE INSERT ON bill_items
WHEN NEW.bill_id <> '$currentId'
BEGIN SELECT RAISE(ABORT, 'cycle rebuild failed'); END
''');
        await expectLater(
          fixture.creditAccountAppService.editAccount(
            EditCreditLiabilityAccountCommand(
              accountId: account.id,
              name: 'Updated',
              billingDay: const Patch.set(15),
            ),
          ),
          throwsA(isA<Exception>()),
        );
        expect(
          (await fixture.creditAccountRepository.findByAccountId(
            account.id,
          ))!.billingDay,
          5,
        );
        expect(
          (await fixture.accountRepository.findById(account.id))!.name,
          beforeName,
        );
        expect(
          await fixture.database.select(fixture.database.bills).get(),
          beforeBills,
        );
        expect(
          await fixture.database.select(fixture.database.billItems).get(),
          beforeItems,
        );
        await fixture.database.customStatement(
          'DROP TRIGGER reject_cycle_rebuild',
        );
      },
    );

    test(
      'manual creation permits arbitrary future periods and clears suppression',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        final account = await fixture.createLoanAccount();
        final period = BillPeriod.fromInt(209912);
        final suppressions = DriftBillGenerationSuppressionRepository(
          fixture.database,
        );
        await suppressions.suppress(account.id, period);
        await fixture.generation.generateBillForPeriod(
          accountId: account.id,
          period: period,
          now: fixture.today,
        );
        final bill = (await fixture.billRepository.findByAccountAndPeriod(
          account.id,
          period,
        ))!;
        expect(bill.items, isEmpty);
        expect(await suppressions.isSuppressed(account.id, period), isFalse);
        expect(
          await fixture.billRepository.listBillsByAccount(account.id),
          hasLength(1),
        );
      },
    );

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
          const Money(minorUnits: 9000),
        );

        await fixture.generation.refreshCurrentAndFutureBillsForAccount(
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
          repaymentDate: DateTime(2026, 6, 4),
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
            repaymentDate: DateTime(2026, 6, 5),
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
                borrowingDate: DateTime(2026, 6, 25),
                stageTerms: InstallmentContractTerms.singleStage(
                  totalPeriods: 1,
                  firstDate: DateTime(2026, 7, 25),
                  method: InstallmentRepaymentMethod.equalPrincipal,
                  accrual: InterestAccrualMethod.daily,
                ),
              ),
            );

        await fixture.generation.refreshCurrentAndFutureBillsForAccount(
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
          subtype: AccountSubtype.fund,
          profileKey: 'ledger.fund',
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
      'generates the empty current loan bill and future obligations without backfilling history',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        final account = await fixture.createLoanAccount();
        final contractId = fixture.ids.newId();
        final schedules = [
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
        ];
        await fixture.installmentRepository.insertAggregate(
          InstallmentContract(
            id: contractId,
            liabilityAccountId: account.id,
            installmentType: InstallmentType.disbursement,
            sourceRefId: 'tx-borrowing',
            principal: const Money(minorUnits: 120000),
            borrowingDate: DateTime(2026, 6, 1),
            status: InstallmentContractStatus.active,
            createdAt: DateTime(2026, 6, 1),
            stageTerms: InstallmentContractTerms.singleStage(
              id: contractId,
              totalPeriods: 3,
              firstDate: DateTime(2026, 7, 1),
              lastDate: DateTime(2026, 9, 1),
              method: InstallmentRepaymentMethod.equalPrincipal,
              accrual: InterestAccrualMethod.daily,
              feeMinor: 0,
            ),
            schedules: schedules,
          ),
        );
        final aggregate = (await fixture.installmentRepository.findContract(
          contractId,
        ))!;
        aggregate.skipSchedule(
          schedules.singleWhere((schedule) => schedule.periodNo == 2).id,
        );
        await fixture.installmentRepository.saveAggregate(aggregate);

        await fixture.generation.generateDueBills(now: DateTime(2026, 8, 15));

        final bills = await fixture.billRepository.listBillsByAccount(
          account.id,
        );
        expect(bills, hasLength(2));
        final current = bills.singleWhere(
          (bill) => bill.period == BillPeriod.fromInt(202608),
        );
        expect(current.items, isEmpty);
        expect(current.status, BillStatus.settled);
        final future = bills.singleWhere(
          (bill) => bill.period == BillPeriod.fromInt(202609),
        );
        expect(future.expectedPrincipal.minorUnits, 60000);
        expect(
          bills.any((bill) => bill.period == BillPeriod.fromInt(202607)),
          isFalse,
        );
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
        aggregate.contract.schedules.first.markPending();
        aggregate.contract.refreshStatusFromSchedules();
        await fixture.installmentRepository.saveAggregate(aggregate.contract);

        await fixture.generation.refreshCurrentAndFutureBillsForAccount(
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

    for (final scenario in [
      (paidMinor: 0, refreshFirst: false),
      (paidMinor: 20000, refreshFirst: false),
      (paidMinor: 60000, refreshFirst: false),
      (paidMinor: 20000, refreshFirst: true),
    ]) {
      final paidMinor = scenario.paidMinor;
      test(
        'cross-month schedule with $paidMinor paid, old refresh first ${scenario.refreshFirst}, detaches references and projects the full amount',
        () async {
          final fixture = _Fixture();
          addTearDown(fixture.close);
          final account = await fixture.createLoanAccount();
          final contractId = fixture.ids.newId();
          final schedule = InstallmentSchedule(
            id: fixture.ids.newId(),
            contractId: contractId,
            periodNo: 1,
            expectedRepaymentDate: DateTime(2026, 7, 1),
            expectedPrincipal: const Money(minorUnits: 60000),
            expectedInterest: Money.zero(),
            expectedFee: Money.zero(),
            status: InstallmentScheduleStatus.pending,
            createdAt: DateTime(2026, 6, 1),
          );
          await fixture.installmentRepository.insertAggregate(
            InstallmentContract(
              id: contractId,
              liabilityAccountId: account.id,
              installmentType: InstallmentType.disbursement,
              sourceRefId: 'tx-borrowing',
              principal: const Money(minorUnits: 60000),
              borrowingDate: DateTime(2026, 6, 1),
              status: InstallmentContractStatus.active,
              createdAt: DateTime(2026, 6, 1),
              stageTerms: InstallmentContractTerms.singleStage(
                id: contractId,
                totalPeriods: 1,
                firstDate: DateTime(2026, 7, 1),
                lastDate: DateTime(2026, 7, 1),
                method: InstallmentRepaymentMethod.equalPrincipal,
                accrual: InterestAccrualMethod.daily,
                feeMinor: 0,
              ),
              schedules: [schedule],
            ),
          );

          await fixture.generation.generateDueBills(now: DateTime(2026, 7, 15));
          final july = (await fixture.billRepository.listBillsByAccount(
            account.id,
          )).singleWhere((bill) => bill.period == BillPeriod.fromInt(202607));
          final originalItemId = july.items.single.id;
          if (paidMinor > 0) {
            await fixture.repaymentAppService.createBillRepayment(
              CreateBillRepaymentCommand(
                billId: july.id,
                repaymentDate: DateTime(2026, 7, 15),
                allocations: [
                  BillRepaymentAllocation(
                    billItemId: originalItemId,
                    allocated: RepaymentAmountDto(
                      principal: Money(minorUnits: paidMinor),
                      interest: Money.zero(),
                      fee: Money.zero(),
                      discount: Money.zero(),
                    ),
                  ),
                ],
              ),
            );
          }

          final contract = await fixture.installmentRepository.findContract(
            schedule.contractId,
          );
          contract!.schedules
              .singleWhere((candidate) => candidate.id == schedule.id)
              .reviseExpectation(expectedRepaymentDate: DateTime(2026, 8, 1));
          await fixture.installmentRepository.saveAggregate(contract);

          if (scenario.refreshFirst) {
            final before = await fixture.database
                .select(fixture.database.repaymentItems)
                .get();
            await fixture.database.customStatement('''
CREATE TRIGGER reject_bill_refresh BEFORE DELETE ON bill_items
WHEN OLD.id = '$originalItemId'
BEGIN SELECT RAISE(ABORT, 'bill refresh failed'); END
''');
            await expectLater(
              fixture.generation.refreshBill(july.id),
              throwsA(isA<Exception>()),
            );
            expect(
              await fixture.database
                  .select(fixture.database.repaymentItems)
                  .get(),
              before,
            );
            expect(
              (await fixture.billRepository.findBill(july.id))!.items.single.id,
              originalItemId,
            );
            await fixture.database.customStatement(
              'DROP TRIGGER reject_bill_refresh',
            );
            await fixture.generation.refreshBill(july.id);
          }

          await fixture.generation.generateDueBills(now: DateTime(2026, 8, 15));
          final august = (await fixture.billRepository.listBillsByAccount(
            account.id,
          )).singleWhere((bill) => bill.period == BillPeriod.fromInt(202608));
          expect(august.items.single.id, isNot(originalItemId));
          expect(august.items.single.scheduleId, schedule.id);
          expect(august.items.single.expectedPrincipal.minorUnits, 60000);

          await fixture.generation.refreshBill(july.id);

          final syncedJuly = await fixture.billRepository.findBill(july.id);
          expect(syncedJuly!.status, BillStatus.settled);
          expect(syncedJuly.items, isEmpty);
          expect(
            await fixture.repaymentRepository.listItemsByBillItem(
              originalItemId,
            ),
            isEmpty,
          );
          if (paidMinor > 0) {
            final repayment = (await fixture.repaymentRepository.listByTarget(
              RepaymentTargetType.bill,
              july.id,
            )).single;
            expect(repayment.items.single.billItemId, isNull);
            expect(
              repayment.items.single.allocated.principal.minorUnits,
              paidMinor,
            );
            expect(repayment.repaymentDate, DateTime(2026, 7, 15));
            final edit = await fixture.repaymentAppService
                .loadBillRepaymentEditView(repayment.id);
            expect(edit!.allocations.single.billItemId, isNull);
            expect(
              edit.allocations.single.allocated.principal.minorUnits,
              paidMinor,
            );
          }
          final validation = await InstallmentStatusRepairAppService(
            installments: fixture.installmentRepository,
            bills: fixture.billRepository,
            repayments: fixture.repaymentRepository,
            transactionRunner: fixture.runner,
          ).validateAndRepair(contractId);
          expect(validation.issues, isEmpty);
          expect(
            (await fixture.installmentRepository.listSchedules(
              contractId,
            )).single.status,
            InstallmentScheduleStatus.pending,
          );
          expect(
            (await fixture.installmentRepository.findContract(
              contractId,
            ))!.status,
            InstallmentContractStatus.active,
          );
        },
      );
    }

    test('bill refresh does not drive installment aggregate status', () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      final account = await fixture.createLoanAccount();
      final contractId = fixture.ids.newId();
      final schedule = InstallmentSchedule(
        id: fixture.ids.newId(),
        contractId: contractId,
        periodNo: 1,
        expectedRepaymentDate: DateTime(2026, 7, 1),
        expectedPrincipal: const Money(minorUnits: 60000),
        expectedInterest: Money.zero(),
        expectedFee: Money.zero(),
        status: InstallmentScheduleStatus.pending,
        createdAt: DateTime(2026, 6, 1),
      );
      final contract = InstallmentContract(
        id: contractId,
        liabilityAccountId: account.id,
        installmentType: InstallmentType.disbursement,
        sourceRefId: 'tx-borrowing',
        principal: const Money(minorUnits: 60000),
        borrowingDate: DateTime(2026, 6, 1),
        status: InstallmentContractStatus.active,
        createdAt: DateTime(2026, 6, 1),
        stageTerms: InstallmentContractTerms.singleStage(
          id: fixture.ids.newId(),
          totalPeriods: 1,
          firstDate: DateTime(2026, 7, 1),
          lastDate: DateTime(2026, 7, 1),
          method: InstallmentRepaymentMethod.equalPrincipal,
          accrual: InterestAccrualMethod.daily,
          feeMinor: 0,
        ),
        schedules: [schedule],
      );
      await fixture.installmentRepository.insertAggregate(contract);
      await fixture.generation.generateDueBills(now: DateTime(2026, 7, 15));
      final bill = (await fixture.billRepository.listBillsByAccount(
        account.id,
      )).single;
      final billItem = bill.items.single;
      final repaymentId = fixture.ids.newId();
      final repayment = Repayment(
        id: repaymentId,
        repaymentType: RepaymentType.bill,
        targetType: RepaymentTargetType.bill,
        targetId: bill.id,
        repaymentDate: DateTime(2026, 7, 1),
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

      final persistedContract = (await fixture.installmentRepository
          .findContract(contract.id))!;
      persistedContract.markSchedulePaid(schedule.id);
      await fixture.installmentRepository.saveAggregate(persistedContract);
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
        final originalRepayment = june.items.single.repaymentDate;

        await fixture.generation.updateBillWindow(
          billId: june.id,
          startDate: DateTime(2026, 6, 10),
          billingDate: DateTime(2026, 6, 20),
        );

        final updated = (await fixture.billRepository.findBill(june.id))!;
        expect(updated.items.single.startInclusive, DateTime(2026, 6, 10));
        expect(updated.items.single.endInclusive, DateTime(2026, 6, 19));
        expect(updated.items.single.repaymentDate, originalRepayment);
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
      bookRepository: FakeBookRepository(),
      transactionRunner: runner,
      ledgerPostingService: postingService,
      transactionRepository: postingRepository,
      idGenerator: ids,
    );
    creditAccountAppService = CreditAccountAppServiceImpl(
      ledger: LedgerCreditAccountPort(
        accountAppService,
        accountDeletion: accountAppService,
      ),
      creditAccounts: creditAccountRepository,
      bills: billRepository,
      installments: installmentRepository,
      repayments: repaymentRepository,
      suppressions: DriftBillGenerationSuppressionRepository(database),
      billSources: DriftCreditBillSourceRepository(database),
      now: () => today,
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
      now: () => today,
      transactionRunner: runner,
      idGenerator: ids,
    );
    repaymentAppService = BillRepaymentAppServiceImpl(
      bills: billRepository,
      repayments: repaymentRepository,
      installments: installmentRepository,
      ledger: creditLedgerPort,
      transactionRunner: runner,
      idGenerator: ids,
    );
  }

  var today = DateTime(2026, 6, 4);
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
    bookRepository: DriftBookRepository(database),
    transactionRunner: runner,
    transactionRepository: postingRepository,
    transactionGroupRepository: postingRepository,
    accountRepository: accountRepository,
    transactionTagRepository: FakeTransactionTagRepository(),
    counterpartyRepository: FakeCounterpartyRepository(),
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
        lineRead: DriftTransactionLineReadRepository(database),
        accountQuery: accountQueryService,
        counterpartyRepository: FakeCounterpartyRepository(),
        metricsSource: DriftLedgerMetricsSource(database),
      );
  late final CreditAccountAppService creditAccountAppService;
  late final TransactionPostingAppService postingAppService;
  late final CreditBillGenerationAppService generation;
  late final BillRepaymentAppService repaymentAppService;

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
  createInterestOnlyInstallment({
    required DateTime repaymentDate,
    CreditLedgerAccountSnapshot? liabilityAccount,
  }) async {
    final account = liabilityAccount ?? await createLoanAccount();
    final contractId = ids.newId();
    final schedule = InstallmentSchedule(
      id: ids.newId(),
      contractId: contractId,
      periodNo: 1,
      expectedRepaymentDate: repaymentDate,
      expectedPrincipal: Money.zero(),
      expectedInterest: const Money(minorUnits: 1000),
      expectedFee: Money.zero(),
      status: InstallmentScheduleStatus.pending,
      createdAt: DateTime(2026, 5, 1),
    );
    final contract = InstallmentContract(
      id: contractId,
      liabilityAccountId: account.id,
      installmentType: InstallmentType.disbursement,
      sourceRefId: 'tx-borrowing',
      principal: const Money(minorUnits: 60000),
      borrowingDate: DateTime(2026, 5, 1),
      status: InstallmentContractStatus.active,
      createdAt: DateTime(2026, 5, 1),
      stageTerms: InstallmentContractTerms.singleStage(
        id: ids.newId(),
        totalPeriods: 2,
        firstDate: repaymentDate,
        lastDate: DateTime(
          repaymentDate.year,
          repaymentDate.month + 1,
          repaymentDate.day,
        ),
        method: InstallmentRepaymentMethod.interestFirst,
        accrual: InterestAccrualMethod.daily,
        feeMinor: 0,
      ),
      schedules: [
        schedule,
        InstallmentSchedule(
          id: ids.newId(),
          contractId: contractId,
          periodNo: 2,
          expectedRepaymentDate: DateTime(
            repaymentDate.year,
            repaymentDate.month + 1,
            repaymentDate.day,
          ),
          expectedPrincipal: const Money(minorUnits: 60000),
          expectedInterest: const Money(minorUnits: 1000),
          expectedFee: Money.zero(),
          status: InstallmentScheduleStatus.pending,
          createdAt: DateTime(2026, 5, 1),
        ),
      ],
    );
    await installmentRepository.insertAggregate(contract);
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
    String? bookId,
    required String accountId,
    required Money amount,
    required DateTime occurredAt,
  }) {
    return postingAppService.createExpense(
      CreateExpenseCommand(
        bookId: bookId,
        amount: amount,
        categoryAllocations: singleAllocation(
          accountId: 'expense-food',
          amount: amount,
        ),
        settlementAllocations: singleAllocation(
          accountId: accountId,
          amount: amount,
        ),
        occurredAt: occurredAt,
      ),
    );
  }

  Future<PostedTransactionResult> postRefund({
    String? bookId,
    required String accountId,
    required String parentTransactionId,
    required Money amount,
    required DateTime occurredAt,
  }) {
    return postingAppService.createRefund(
      CreateRefundCommand(
        bookId: bookId,
        amount: amount,
        parentTransactionId: parentTransactionId,
        categoryAllocations: const [],
        settlementAllocations: singleAllocation(
          accountId: accountId,
          amount: amount,
        ),
        occurredAt: occurredAt,
      ),
    );
  }

  Future<void> close() => database.close();
}
