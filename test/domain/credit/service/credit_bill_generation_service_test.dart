import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/entity/credit_liability_account.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/bill_generation_suppression_repository.dart';
import 'package:smartflow/domain/credit/port/credit_account_repository.dart';
import 'package:smartflow/domain/credit/port/credit_bill_source_repository.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/service/bill/credit_bill_generation_service.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/bill_period.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/domain/credit/valobj/credit_account_enums.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_amount_breakdown.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

import '../../../helper/sequential_id_generator.dart';

void main() {
  group('CreditBillGenerationService', () {
    test(
      'refreshes open credit bill from current consumption source',
      () async {
        final fixture = _Fixture();
        final account = fixture.creditAccount();
        fixture.creditAccounts.put(account);

        fixture.billSources.netConsumptionMinorValue = 7000;
        await fixture.service.generateDueBillsForAccount(
          account: account,
          now: DateTime(2026, 6, 4),
        );

        var bill = fixture.bills
            .byAccount(account.accountId)
            .singleWhere((bill) => bill.period == BillPeriod.fromInt(202606));
        final itemId = bill.items.single.id;
        expect(bill.period, BillPeriod.fromInt(202606));
        expect(bill.status, BillStatus.open);
        expect(
          bill.items.single.expectedPrincipal,
          const Money(minorUnits: 7000),
        );

        fixture.billSources.netConsumptionMinorValue = 9000;
        await fixture.service.refreshBill(bill.id);

        bill = fixture.bills
            .byAccount(account.accountId)
            .singleWhere((bill) => bill.period == BillPeriod.fromInt(202606));
        expect(bill.items.single.id, itemId);
        expect(
          bill.items.single.expectedPrincipal,
          const Money(minorUnits: 9000),
        );
      },
    );

    test(
      'cross-month loan schedule creates a new bill item identity',
      () async {
        final fixture = _Fixture();
        final account = fixture.loanAccount();
        fixture.creditAccounts.put(account);
        final contract = fixture.contract(accountId: account.accountId);
        final schedule = fixture.schedule(contractId: contract.id);
        fixture.installments.putContract(contract);
        fixture.installments.replaceSchedules(contract.id, [schedule]);

        await fixture.service.generateDueBillsForAccount(
          account: account,
          now: DateTime(2026, 7, 15),
        );
        final july = fixture.bills
            .byAccount(account.accountId)
            .singleWhere((bill) => bill.period == BillPeriod.fromInt(202607));
        final originalItemId = july.items.single.id;

        schedule.expectedRepaymentDate = DateTime(2026, 8, 1);

        await fixture.service.generateDueBillsForAccount(
          account: account,
          now: DateTime(2026, 8, 15),
        );
        final august = fixture.bills
            .byAccount(account.accountId)
            .singleWhere((bill) => bill.period == BillPeriod.fromInt(202608));
        expect(august.items.single.id, isNot(originalItemId));
        expect(august.items.single.scheduleId, schedule.id);

        await fixture.service.refreshBill(july.id);

        final syncedJuly = await fixture.bills.findBill(july.id);
        expect(syncedJuly!.items, isEmpty);
        expect(syncedJuly.status, BillStatus.settled);
      },
    );

    test(
      'does not regress settled historical credit bill during generation',
      () async {
        final fixture = _Fixture();
        final account = fixture.creditAccount();
        fixture.creditAccounts.put(account);
        final period = BillPeriod.fromInt(202606);
        final window = account.nextCreditBillWindow(period);
        await fixture.bills.saveBill(
          Bill(
            id: 'settled-bill',
            accountId: account.accountId,
            period: period,
            window: window,
            status: BillStatus.settled,
            items: [
              BillItem(
                id: 'settled-consumption',
                billId: 'settled-bill',
                itemType: BillItemType.consumption,
                repaymentDate: window.repaymentDate,
                expectedPrincipal: const Money(minorUnits: 5000),
                expectedInterest: Money.zero(),
                expectedFee: Money.zero(),
                status: BillItemStatus.paid,
              ),
            ],
          ),
        );
        fixture.billSources.netConsumptionMinorValue = 9000;

        await fixture.service.generateDueBillsForAccount(
          account: account,
          now: DateTime(2026, 6, 10),
        );

        final settled = await fixture.bills.findBill('settled-bill');
        expect(settled!.status, BillStatus.settled);
        expect(
          settled.items.single.expectedPrincipal,
          const Money(minorUnits: 5000),
        );
      },
    );

    test(
      'refresh returns installment status projection without patching aggregates',
      () async {
        final fixture = _Fixture();
        final account = fixture.loanAccount();
        fixture.creditAccounts.put(account);
        final contract = fixture.contract(
          accountId: account.accountId,
          status: InstallmentContractStatus.settled,
        );
        final schedule = fixture.schedule(
          contractId: contract.id,
          status: InstallmentScheduleStatus.paid,
        );
        fixture.installments.putContract(contract);
        fixture.installments.replaceSchedules(contract.id, [schedule]);
        await fixture.bills.saveBill(
          Bill(
            id: 'loan-bill',
            accountId: account.accountId,
            period: BillPeriod.fromInt(202607),
            status: BillStatus.settled,
            items: [
              BillItem(
                id: 'installment-item',
                billId: 'loan-bill',
                itemType: BillItemType.installment,
                contractId: contract.id,
                scheduleId: schedule.id,
                repaymentDate: schedule.expectedRepaymentDate,
                expectedPrincipal: const Money(minorUnits: 60000),
                expectedInterest: Money.zero(),
                expectedFee: Money.zero(),
                status: BillItemStatus.paid,
              ),
            ],
          ),
        );
        await fixture.repayments.saveRepayment(
          Repayment(
            id: 'repayment',
            repaymentType: RepaymentType.bill,
            targetType: RepaymentTargetType.bill,
            targetId: 'loan-bill',
            repaymentDate: DateTime(2026, 7, 1),
            items: [
              RepaymentItem(
                id: 'repayment-item',
                repaymentId: 'repayment',
                billItemId: 'installment-item',
                allocated: const RepaymentAmountBreakdown(
                  principal: Money(minorUnits: 60000),
                  interest: Money(minorUnits: 0),
                  fee: Money(minorUnits: 0),
                  discount: Money(minorUnits: 0),
                ),
              ),
            ],
          ),
        );
        schedule.expectedPrincipal = const Money(minorUnits: 70000);

        final result = await fixture.service.refreshBill('loan-bill');

        final bill = await fixture.bills.findBill('loan-bill');
        expect(bill!.status, BillStatus.billed);
        expect(bill.items.single.status, BillItemStatus.partiallyPaid);
        expect(
          bill.items.single.expectedPrincipal,
          const Money(minorUnits: 70000),
        );
        expect(result.scheduleStatuses, {
          schedule.id: BillItemStatus.partiallyPaid,
        });
        final syncedSchedule = await fixture.installments.findSchedule(
          schedule.id,
        );
        expect(syncedSchedule!.status, InstallmentScheduleStatus.paid);
        final syncedContract = await fixture.installments.findContract(
          contract.id,
        );
        expect(syncedContract!.status, InstallmentContractStatus.settled);
      },
    );

    test(
      'keeps existing credit bill window and uses new cycle for next bill',
      () async {
        final fixture = _Fixture();
        final account = fixture.creditAccount();
        fixture.creditAccounts.put(account);
        fixture.billSources.netConsumptionMinorValue = 1000;
        await fixture.service.generateDueBillsForAccount(
          account: account,
          now: DateTime(2026, 6, 4),
        );
        final june = fixture.bills
            .byAccount(account.accountId)
            .singleWhere((bill) => bill.period == BillPeriod.fromInt(202606));
        final originalWindow = june.window!;

        account.billingDay = 10;
        account.repaymentDay = 28;
        fixture.billSources.netConsumptionMinorValue = 2000;
        await fixture.service.generateDueBillsForAccount(
          account: account,
          now: DateTime(2026, 6, 4),
        );
        await fixture.service.generateDueBillsForAccount(
          account: account,
          now: DateTime(2026, 6, 10),
        );

        final bills = fixture.bills.byAccount(account.accountId);
        final syncedJune = bills.singleWhere(
          (bill) => bill.period == BillPeriod.fromInt(202606),
        );
        final july = bills.singleWhere(
          (bill) => bill.period == BillPeriod.fromInt(202607),
        );
        expect(syncedJune.window, originalWindow);
        expect(syncedJune.status, BillStatus.billed);
        expect(july.status, BillStatus.open);
        expect(july.window!.startDate, originalWindow.billingDate);
        expect(july.window!.billingDate, DateTime(2026, 7, 10));
        expect(july.window!.repaymentDate, DateTime(2026, 7, 28));
      },
    );

    test(
      'on the billing day freezes the previous open bill and opens the next',
      () async {
        final fixture = _Fixture();
        final account = fixture.creditAccount();
        fixture.creditAccounts.put(account);
        fixture.billSources.netConsumptionMinorValue = 7000;

        await fixture.service.generateDueBillsForAccount(
          account: account,
          now: DateTime(2026, 6, 4),
        );
        final june = fixture.bills
            .byAccount(account.accountId)
            .singleWhere((bill) => bill.period == BillPeriod.fromInt(202606));
        expect(june.status, BillStatus.open);

        await fixture.service.generateDueBillsForAccount(
          account: account,
          now: DateTime(2026, 6, 5),
        );

        final syncedJune = fixture.bills
            .byAccount(account.accountId)
            .singleWhere((bill) => bill.period == BillPeriod.fromInt(202606));
        final july = fixture.bills
            .byAccount(account.accountId)
            .singleWhere((bill) => bill.period == BillPeriod.fromInt(202607));
        expect(syncedJune.status, BillStatus.billed);
        expect(july.status, BillStatus.open);
        expect(july.window!.startDate, syncedJune.window!.billingDate);
      },
    );

    test(
      'keeps billing-day consumption in the current bill when configured',
      () async {
        final fixture = _Fixture();
        final account = fixture.creditAccount()..billingDayToNext = false;
        fixture.creditAccounts.put(account);
        fixture.billSources.netConsumptionMinorValue = 7000;
        await fixture.service.generateDueBillsForAccount(
          account: account,
          now: DateTime(2026, 6, 4),
        );

        await fixture.service.generateDueBillsForAccount(
          account: account,
          now: DateTime(2026, 6, 5),
        );

        final june = fixture.bills
            .byAccount(account.accountId)
            .singleWhere((bill) => bill.period == BillPeriod.fromInt(202606));
        expect(june.status, BillStatus.open);
        expect(fixture.bills.byAccount(account.accountId), hasLength(1));

        await fixture.service.generateDueBillsForAccount(
          account: account,
          now: DateTime(2026, 6, 6),
        );

        expect(
          (await fixture.bills.findBill(june.id))!.status,
          BillStatus.billed,
        );
        expect(
          await fixture.bills.findByAccountAndPeriod(
            account.accountId,
            BillPeriod.fromInt(202607),
          ),
          isNotNull,
        );
      },
    );

    test('does not backfill a missing previous credit bill', () async {
      final fixture = _Fixture();
      final account = fixture.creditAccount();
      fixture.creditAccounts.put(account);

      // 首次生成恰逢出账日：上一期（6 月）不存在，不补建，只创建当前 OPEN 账单。
      await fixture.service.generateDueBillsForAccount(
        account: account,
        now: DateTime(2026, 6, 5),
      );

      final bills = fixture.bills.byAccount(account.accountId);
      expect(bills.map((bill) => bill.period).toList(), [
        BillPeriod.fromInt(202607),
      ]);
      expect(bills.single.status, BillStatus.open);
    });

    test('deletes a bill without repayment records', () async {
      final fixture = _Fixture();
      final account = fixture.creditAccount();
      fixture.creditAccounts.put(account);
      await fixture.service.generateDueBillsForAccount(
        account: account,
        now: DateTime(2026, 6, 4),
      );
      final june = fixture.bills
          .byAccount(account.accountId)
          .singleWhere((bill) => bill.period == BillPeriod.fromInt(202606));

      await fixture.service.deleteBill(june.id);

      expect(await fixture.bills.findBill(june.id), isNull);
    });

    test(
      'does not automatically recreate a deleted current loan bill',
      () async {
        final fixture = _Fixture();
        final account = fixture.loanAccount();
        fixture.creditAccounts.put(account);
        await fixture.service.generateDueBillsForAccount(
          account: account,
          now: DateTime(2026, 6, 4),
        );
        final june = fixture.bills
            .byAccount(account.accountId)
            .singleWhere((bill) => bill.period == BillPeriod.fromInt(202606));

        await fixture.service.deleteBill(june.id);
        await fixture.service.generateDueBillsForAccount(
          account: account,
          now: DateTime(2026, 6, 4),
        );

        expect(
          await fixture.bills.findByAccountAndPeriod(
            account.accountId,
            BillPeriod.fromInt(202606),
          ),
          isNull,
        );
      },
    );

    test(
      'does not automatically recreate a deleted current credit bill',
      () async {
        final fixture = _Fixture();
        final account = fixture.creditAccount();
        fixture.creditAccounts.put(account);
        fixture.billSources.netConsumptionMinorValue = 1000;
        await fixture.service.generateDueBillsForAccount(
          account: account,
          now: DateTime(2026, 6, 4),
        );
        final june = fixture.bills
            .byAccount(account.accountId)
            .singleWhere((bill) => bill.period == BillPeriod.fromInt(202606));

        await fixture.service.deleteBill(june.id);
        await fixture.service.generateDueBillsForAccount(
          account: account,
          now: DateTime(2026, 6, 4),
        );

        expect(
          await fixture.bills.findByAccountAndPeriod(
            account.accountId,
            BillPeriod.fromInt(202606),
          ),
          isNull,
        );
      },
    );

    test('explicit generation restores a suppressed credit bill', () async {
      final fixture = _Fixture();
      final account = fixture.creditAccount();
      fixture.creditAccounts.put(account);
      await fixture.service.generateDueBillsForAccount(
        account: account,
        now: DateTime(2026, 6, 4),
      );
      final june = fixture.bills
          .byAccount(account.accountId)
          .singleWhere((bill) => bill.period == BillPeriod.fromInt(202606));

      await fixture.service.deleteBill(june.id);
      await fixture.service.generateBillForPeriod(
        account: account,
        period: BillPeriod.fromInt(202606),
        now: DateTime(2026, 6, 4),
      );

      expect(
        await fixture.bills.findByAccountAndPeriod(
          account.accountId,
          BillPeriod.fromInt(202606),
        ),
        isNotNull,
      );
      expect(
        await fixture.suppressions.isSuppressed(
          account.accountId,
          BillPeriod.fromInt(202606),
        ),
        isFalse,
      );
    });

    test(
      'late generation freezes existing open bills and resets after a gap',
      () async {
        final fixture = _Fixture();
        final account = fixture.creditAccount();
        fixture.creditAccounts.put(account);
        fixture.billSources.netConsumptionMinorValue = 1000;
        await fixture.service.generateDueBillsForAccount(
          account: account,
          now: DateTime(2026, 6, 4),
        );

        await fixture.service.generateDueBillsForAccount(
          account: account,
          now: DateTime(2026, 8, 10),
        );

        final june = fixture.bills
            .byAccount(account.accountId)
            .singleWhere((bill) => bill.period == BillPeriod.fromInt(202606));
        final september = fixture.bills
            .byAccount(account.accountId)
            .singleWhere((bill) => bill.period == BillPeriod.fromInt(202609));
        expect(june.status, BillStatus.billed);
        expect(september.window!.startDate, DateTime(2026, 8, 5));
        expect(september.window!.billingDate, DateTime(2026, 9, 5));
      },
    );

    test('rejects deleting a bill that has repayment records', () async {
      final fixture = _Fixture();
      final account = fixture.creditAccount();
      fixture.creditAccounts.put(account);
      await fixture.service.generateDueBillsForAccount(
        account: account,
        now: DateTime(2026, 6, 4),
      );
      final june = fixture.bills
          .byAccount(account.accountId)
          .singleWhere((bill) => bill.period == BillPeriod.fromInt(202606));
      await fixture.repayments.saveRepayment(
        Repayment(
          id: 'repayment',
          repaymentType: RepaymentType.bill,
          targetType: RepaymentTargetType.bill,
          targetId: june.id,
          repaymentDate: DateTime(2026, 7, 1),
          items: [
            RepaymentItem(
              id: 'repayment-item',
              repaymentId: 'repayment',
              billItemId: june.items.first.id,
              allocated: RepaymentAmountBreakdown(
                principal: const Money(minorUnits: 1),
                interest: Money.zero(),
                fee: Money.zero(),
                discount: Money.zero(),
              ),
            ),
          ],
        ),
      );

      await expectLater(
        fixture.service.deleteBill(june.id),
        throwsA(
          isA<BusinessException>().having(
            (e) => e.code,
            'code',
            CreditErrorCode.billHasRepayments.code,
          ),
        ),
      );
    });

    test(
      'updates bill window and refreshes the consumption projection',
      () async {
        final fixture = _Fixture();
        final account = fixture.creditAccount();
        fixture.creditAccounts.put(account);
        fixture.billSources.netConsumptionMinorValue = 5000;
        await fixture.service.generateDueBillsForAccount(
          account: account,
          now: DateTime(2026, 6, 4),
        );
        final june = fixture.bills
            .byAccount(account.accountId)
            .singleWhere((bill) => bill.period == BillPeriod.fromInt(202606));
        final originalRepayment = june.window!.repaymentDate;

        await fixture.service.updateBillWindow(
          billId: june.id,
          startDate: DateTime(2026, 6, 10),
          billingDate: DateTime(2026, 6, 20),
        );

        final updated = (await fixture.bills.findBill(june.id))!;
        expect(updated.window!.startDate, DateTime(2026, 6, 10));
        expect(updated.window!.billingDate, DateTime(2026, 6, 20));
        expect(updated.window!.repaymentDate, originalRepayment);
        expect(
          updated.items.single.expectedPrincipal,
          const Money(minorUnits: 5000),
        );
      },
    );

    test('rejects an invalid or overlapping bill window', () async {
      final fixture = _Fixture();
      final account = fixture.creditAccount();
      fixture.creditAccounts.put(account);
      // 预置上一期账单，使与上一期的重叠校验有比对对象。
      final mayWindow = account.nextCreditBillWindow(
        BillPeriod.fromInt(202605),
      );
      await fixture.bills.saveBill(
        Bill(
          id: 'may-bill',
          accountId: account.accountId,
          period: BillPeriod.fromInt(202605),
          window: mayWindow,
          status: BillStatus.billed,
          items: const [],
        ),
      );
      await fixture.service.generateDueBillsForAccount(
        account: account,
        now: DateTime(2026, 6, 4),
      );
      final june = fixture.bills
          .byAccount(account.accountId)
          .singleWhere((bill) => bill.period == BillPeriod.fromInt(202606));

      await expectLater(
        fixture.service.updateBillWindow(
          billId: june.id,
          startDate: DateTime(2026, 6, 10),
          billingDate: DateTime(2026, 6, 5),
        ),
        throwsA(
          isA<BusinessException>().having(
            (e) => e.code,
            'code',
            CreditErrorCode.billWindowInvalid.code,
          ),
        ),
      );

      // 出账日晚于还款日。
      await expectLater(
        fixture.service.updateBillWindow(
          billId: june.id,
          startDate: DateTime(2026, 6, 1),
          billingDate: june.window!.repaymentDate.add(const Duration(days: 1)),
        ),
        throwsA(
          isA<BusinessException>().having(
            (e) => e.code,
            'code',
            CreditErrorCode.billWindowInvalid.code,
          ),
        ),
      );

      // 起始日早于上一期出账日（5 月账单出账日 5-05）。
      await expectLater(
        fixture.service.updateBillWindow(
          billId: june.id,
          startDate: DateTime(2026, 5, 1),
          billingDate: DateTime(2026, 6, 20),
        ),
        throwsA(
          isA<BusinessException>().having(
            (e) => e.code,
            'code',
            CreditErrorCode.billWindowOverlap.code,
          ),
        ),
      );

      // 出账日晚于下一期起始日。
      await fixture.service.generateDueBillsForAccount(
        account: account,
        now: DateTime(2026, 6, 5),
      );
      await expectLater(
        fixture.service.updateBillWindow(
          billId: june.id,
          startDate: DateTime(2026, 5, 6),
          billingDate: DateTime(2026, 6, 20),
        ),
        throwsA(
          isA<BusinessException>().having(
            (e) => e.code,
            'code',
            CreditErrorCode.billWindowOverlap.code,
          ),
        ),
      );
    });
  });
}

class _Fixture {
  _Fixture() {
    service = CreditBillGenerationService(
      creditAccounts: creditAccounts,
      installments: installments,
      repayments: repayments,
      bills: bills,
      suppressions: suppressions,
      billSources: billSources,
      idGenerator: ids,
    );
  }

  final ids = SequentialIdGenerator(prefix: 'domain-bill');
  final creditAccounts = _FakeCreditAccountRepository();
  final installments = _FakeInstallmentRepository();
  final repayments = _FakeRepaymentRepository();
  final bills = _FakeBillRepository();
  final suppressions = _FakeBillGenerationSuppressionRepository();
  final billSources = _FakeCreditBillSourceRepository();

  late final CreditBillGenerationService service;

  CreditLiabilityAccount creditAccount() {
    return CreditLiabilityAccount(
      id: ids.newId(),
      accountId: 'credit-account',
      kind: CreditLiabilityAccountKind.credit,
      billingDay: 5,
      repaymentDay: 25,
      billingDayToNext: true,
    );
  }

  CreditLiabilityAccount loanAccount() {
    return CreditLiabilityAccount(
      id: ids.newId(),
      accountId: 'loan-account',
      kind: CreditLiabilityAccountKind.loan,
      billingDayToNext: true,
    );
  }

  InstallmentContract contract({
    required String accountId,
    InstallmentContractStatus status = InstallmentContractStatus.active,
  }) {
    return InstallmentContract(
      id: ids.newId(),
      liabilityAccountId: accountId,
      sourceType: InstallmentSourceType.disbursement,
      disbursementAccountId: 'asset-account',
      disbursementTransactionId: 'tx-borrowing',
      principal: const Money(minorUnits: 60000),
      borrowingDate: DateTime(2026, 6, 1),
      status: status,
      createdAt: DateTime(2026, 6, 1),
      stageTerms: InstallmentContractTerms.singleStage(
        id: ids.newId(),
        totalPeriods: 1,
        firstDate: DateTime(2026, 7, 1),
        lastDate: DateTime(2026, 7, 1),
        method: InstallmentRepaymentMethod.equalPrincipal,
        accrual: InterestAccrualMethod.daily,
        feeMinor: 0,
      ),
    );
  }

  InstallmentSchedule schedule({
    required String contractId,
    InstallmentScheduleStatus status = InstallmentScheduleStatus.pending,
  }) {
    return InstallmentSchedule(
      id: ids.newId(),
      contractId: contractId,
      periodNo: 1,
      expectedRepaymentDate: DateTime(2026, 7, 1),
      expectedPrincipal: const Money(minorUnits: 60000),
      expectedInterest: Money.zero(),
      expectedFee: Money.zero(),
      status: status,
      createdAt: DateTime(2026, 6, 1),
    );
  }
}

class _FakeBillGenerationSuppressionRepository
    implements BillGenerationSuppressionRepository {
  final _suppressed = <(String, BillPeriod)>{};

  @override
  Future<void> clear(String accountId, BillPeriod period) async {
    _suppressed.remove((accountId, period));
  }

  @override
  Future<void> clearAll(String accountId) async {
    _suppressed.removeWhere((entry) => entry.$1 == accountId);
  }

  @override
  Future<bool> isSuppressed(String accountId, BillPeriod period) async {
    return _suppressed.contains((accountId, period));
  }

  @override
  Future<void> suppress(String accountId, BillPeriod period) async {
    _suppressed.add((accountId, period));
  }
}

class _FakeCreditAccountRepository implements CreditAccountRepository {
  final _accounts = <String, CreditLiabilityAccount>{};

  void put(CreditLiabilityAccount account) {
    _accounts[account.accountId] = account;
  }

  @override
  Future<CreditLiabilityAccount?> findByAccountId(String accountId) async {
    return _accounts[accountId];
  }

  @override
  Future<void> insert(CreditLiabilityAccountDraft draft) async {
    _accounts[draft.accountId] = CreditLiabilityAccount(
      id: draft.id,
      accountId: draft.accountId,
      kind: draft.kind,
      creditLimit: draft.creditLimit,
      billingDay: draft.billingDay,
      repaymentDay: draft.repaymentDay,
      billingDayToNext: draft.billingDayToNext,
    );
  }

  @override
  Future<void> delete(String accountId) async {
    _accounts.remove(accountId);
  }

  @override
  Future<List<CreditLiabilityAccount>> listAll() async {
    return _accounts.values.toList();
  }

  @override
  Future<void> update(
    String accountId,
    CreditLiabilityAccountPersistencePatch patch,
  ) async {
    _accounts[accountId]?.updateParameters(
      CreditLiabilityAccountPatch(
        creditLimit: patch.creditLimit,
        billingDay: patch.billingDay,
        repaymentDay: patch.repaymentDay,
        billingDayToNext: patch.billingDayToNext,
      ),
    );
  }

  @override
  Stream<Map<String, CreditLiabilityAccount>> watchByAccountId() {
    return Stream.value(Map.unmodifiable(_accounts));
  }
}

class _FakeBillRepository implements BillRepository {
  final _bills = <String, Bill>{};

  List<Bill> byAccount(String accountId) {
    return _bills.values.where((bill) => bill.accountId == accountId).toList()
      ..sort((a, b) => a.period.compareTo(b.period));
  }

  @override
  Future<Bill?> findBill(String billId) async => _bills[billId];

  @override
  Future<Bill?> findByAccountAndPeriod(
    String accountId,
    BillPeriod period,
  ) async {
    for (final bill in _bills.values) {
      if (bill.accountId == accountId && bill.period == period) return bill;
    }
    return null;
  }

  @override
  Future<bool> hasUnsettledItems(String accountId) async {
    return byAccount(accountId).any((bill) => bill.hasPendingItems);
  }

  @override
  Future<List<Bill>> listBillsByAccount(String accountId) async {
    return byAccount(accountId);
  }

  @override
  Future<void> replaceBillItems(String billId, List<BillItem> items) async {
    final bill = _bills[billId]!;
    _bills[billId] = Bill(
      id: bill.id,
      accountId: bill.accountId,
      period: bill.period,
      window: bill.window,
      status: bill.status,
      items: items,
      createdAt: bill.createdAt,
    );
  }

  @override
  Future<Bill> saveBill(Bill bill) async {
    _bills[bill.id] = bill;
    return bill;
  }

  @override
  Future<void> updateBill(Bill bill) async {
    _bills[bill.id] = bill;
  }

  @override
  Future<void> deleteBill(String billId) async {
    _bills.remove(billId);
  }
}

class _FakeCreditBillSourceRepository implements CreditBillSourceRepository {
  int netConsumptionMinorValue = 0;

  @override
  Future<int> netConsumptionMinor({
    required String accountId,
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async {
    return netConsumptionMinorValue;
  }
}

class _FakeInstallmentRepository implements InstallmentRepository {
  final _contracts = <String, InstallmentContract>{};
  final _schedules = <String, List<InstallmentSchedule>>{};

  void putContract(InstallmentContract contract) {
    _contracts[contract.id] = contract;
  }

  @override
  Future<void> deleteContract(String contractId) async {
    _contracts.remove(contractId);
    _schedules.remove(contractId);
  }

  @override
  Future<InstallmentContract?> findContract(String id) async {
    return _contracts[id];
  }

  @override
  Future<InstallmentContract?> findContractByDisbursementTransaction(
    String transactionId,
  ) async {
    return _contracts.values
        .where(
          (contract) => contract.disbursementTransactionId == transactionId,
        )
        .firstOrNull;
  }

  @override
  Future<InstallmentSchedule?> findSchedule(String scheduleId) async {
    for (final schedules in _schedules.values) {
      for (final schedule in schedules) {
        if (schedule.id == scheduleId) return schedule;
      }
    }
    return null;
  }

  @override
  Future<List<InstallmentContract>> listContractsByLiabilityAccount(
    String liabilityAccountId,
  ) async {
    return _contracts.values
        .where((contract) => contract.liabilityAccountId == liabilityAccountId)
        .toList();
  }

  @override
  Future<List<InstallmentSchedule>> listSchedules(String contractId) async {
    return List.of(_schedules[contractId] ?? const []);
  }

  @override
  Future<List<InstallmentSchedule>> listSchedulesByLiabilityAccount(
    String liabilityAccountId,
  ) async {
    final contracts = await listContractsByLiabilityAccount(liabilityAccountId);
    return [for (final contract in contracts) ...?_schedules[contract.id]];
  }

  Future<void> replaceSchedules(
    String contractId,
    List<InstallmentSchedule> schedules,
  ) async {
    _schedules[contractId] = List.of(schedules);
  }

  @override
  Future<void> saveContract(InstallmentContract contract) async {
    _contracts[contract.id] = contract;
  }

  @override
  Future<void> insertAggregate(
    InstallmentContract contract,
    List<InstallmentSchedule> schedules,
  ) async {
    _contracts[contract.id] = contract;
    _schedules[contract.id] = List.of(schedules);
  }

  @override
  Future<void> saveAggregate(
    InstallmentContract contract,
    List<InstallmentSchedule> schedules,
  ) async {
    _contracts[contract.id] = contract;
    _schedules[contract.id] = List.of(schedules);
  }
}

class _FakeRepaymentRepository implements RepaymentRepository {
  final _repayments = <String, Repayment>{};

  @override
  Future<void> deleteRepayment(String repaymentId) async {
    _repayments.remove(repaymentId);
  }

  @override
  Future<Repayment?> findByTransaction(String transactionId) async {
    return _repayments.values
        .where((repayment) => repayment.transactionId == transactionId)
        .firstOrNull;
  }

  @override
  Future<Repayment?> findRepayment(String repaymentId) async {
    return _repayments[repaymentId];
  }

  @override
  Future<List<Repayment>> listByTarget(
    RepaymentTargetType targetType,
    String targetId,
  ) async {
    return _repayments.values
        .where(
          (repayment) =>
              repayment.targetType == targetType &&
              repayment.targetId == targetId,
        )
        .toList();
  }

  @override
  Future<List<Repayment>> listByContract(String contractId) async {
    return listByTarget(RepaymentTargetType.contract, contractId);
  }

  @override
  Future<List<RepaymentItem>> listItems(String repaymentId) async {
    return _repayments[repaymentId]?.items ?? const [];
  }

  @override
  Future<List<RepaymentItem>> listItemsByBillItem(String billItemId) async {
    return [
      for (final repayment in _repayments.values)
        for (final item in repayment.items)
          if (item.billItemId == billItemId) item,
    ];
  }

  @override
  Future<Map<String, RepaymentAmountBreakdown>> aggregateItemsByBillItemIds(
    Iterable<String> billItemIds,
  ) async {
    final result = <String, RepaymentAmountBreakdown>{};
    for (final billItemId in billItemIds.toSet()) {
      final allocations = await listItemsByBillItem(billItemId);
      if (allocations.isEmpty) continue;
      result[billItemId] = allocations.fold(
        RepaymentAmountBreakdown.zero,
        (sum, item) => sum + item.allocated,
      );
    }
    return result;
  }

  @override
  Future<void> updateRepayment(Repayment repayment) async {
    _repayments[repayment.id] = repayment;
  }

  @override
  Future<void> saveRepayment(Repayment repayment) async {
    _repayments[repayment.id] = repayment;
  }
}
