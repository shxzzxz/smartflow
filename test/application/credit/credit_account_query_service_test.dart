import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart' as credit;
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/time/month_key.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/domain/credit/port/credit_account_repository.dart';
import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_bill_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_credit_account_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_repayment_repository.dart';

import '../../helper/sequential_id_generator.dart';
import '../../helper/test_app_database.dart';

void main() {
  group('CreditAccountQueryService', () {
    test(
      'derives debt buckets, available credit, and unattributed records',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        await fixture.seedCreditAccount(
          balance: 10000,
          creditLimit: const Money(minorUnits: 15000),
        );
        final schedules = await fixture.seedContract(
          principal: 5000,
          schedulePrincipals: [2000, 3000],
        );
        await fixture.seedBill(
          id: 'bill-billed',
          status: credit.BillStatus.billed,
          items: [
            _BillItemSeed.consumption(id: 'bill-consumption', principal: 3000),
            _BillItemSeed.installment(
              id: 'bill-installment',
              principal: 2000,
              contractId: schedules.contractId,
              scheduleId: schedules.scheduleIds[0],
            ),
          ],
        );
        await fixture.seedBill(
          id: 'bill-open',
          period: credit.BillPeriod(year: 2026, month: 8),
          status: credit.BillStatus.open,
          items: [
            _BillItemSeed.consumption(id: 'open-consumption', principal: 1000),
          ],
        );
        await fixture.repayments.saveRepayment(
          Repayment(
            id: 'unattributed-1',
            repaymentType: credit.RepaymentType.unattributed,
            targetType: credit.RepaymentTargetType.account,
            targetId: 'credit-1',
            items: [
              RepaymentItem(
                id: 'unattributed-item-1',
                repaymentId: 'unattributed-1',
                allocated: credit.RepaymentAmountBreakdown(
                  principal: const Money(minorUnits: 500),
                  interest: Money.zero(),
                  fee: Money.zero(),
                  discount: Money.zero(),
                ),
              ),
            ],
          ),
        );

        final overview = await fixture.query.findOverview('credit-1');

        expect(overview!.liabilityBalance, const Money(minorUnits: 10000));
        expect(overview.availableCredit, const Money(minorUnits: 5000));
        expect(overview.buckets.billDebt, const Money(minorUnits: 6000));
        expect(
          overview.buckets.futureContractDebt,
          const Money(minorUnits: 3000),
        );
        expect(
          overview.buckets.unattributedDebt,
          const Money(minorUnits: 1000),
        );
        expect(overview.unattributedRepayments, hasLength(1));
        expect(
          overview.unattributedRepayments.single.timeSource,
          credit.CreditRepaymentTimeSource.recordCreatedAt,
        );
      },
    );

    test('lists due calendar items and monthly bill summaries', () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      await fixture.seedCreditAccount(balance: 8000);
      final schedules = await fixture.seedContract(
        principal: 5000,
        schedulePrincipals: [2000, 3000],
      );
      await fixture.seedBill(
        id: 'bill-1',
        status: credit.BillStatus.billed,
        items: [
          _BillItemSeed.installment(
            id: 'bill-installment',
            principal: 2000,
            contractId: schedules.contractId,
            scheduleId: schedules.scheduleIds[0],
          ),
          _BillItemSeed.consumption(id: 'bill-consumption', principal: 1000),
        ],
      );

      final dueItems = await fixture.query.listDueCalendarItems(
        credit.CreditDueCalendarQuery(
          from: DateTime(2026, 7),
          until: DateTime(2026, 9),
          accountId: 'credit-1',
        ),
      );
      final summaries = await fixture.query.listMonthlyBillSummaries(
        credit.MonthlyBillSummaryQuery(
          month: MonthKey(year: 2026, month: 7),
          accountId: 'credit-1',
        ),
      );

      expect(dueItems.map((item) => item.source), [
        credit.CreditDueCalendarItemSource.billItem,
        credit.CreditDueCalendarItemSource.billItem,
        credit.CreditDueCalendarItemSource.schedule,
      ]);
      expect(dueItems.last.scheduleId, schedules.scheduleIds[1]);
      expect(summaries, hasLength(1));
      expect(summaries.single.pendingPrincipal, const Money(minorUnits: 3000));
    });
  });
}

class _Fixture {
  _Fixture() {
    query = credit.CreditAccountQueryServiceImpl(
      creditAccounts: creditAccounts,
      bills: bills,
      installments: installments,
      repayments: repayments,
      ledger: ledgerPort,
    );
  }

  final database = createTestDatabase();
  final ledgerPort = _FakeCreditLedgerPort();
  final ids = SequentialIdGenerator(prefix: 'credit-account-query');
  late final DriftCreditAccountRepository creditAccounts =
      DriftCreditAccountRepository(database);
  late final DriftBillRepository bills = DriftBillRepository(database);
  late final DriftInstallmentRepository installments =
      DriftInstallmentRepository(database);
  late final DriftRepaymentRepository repayments = DriftRepaymentRepository(
    database,
  );
  late final credit.CreditAccountQueryService query;

  Future<void> seedCreditAccount({
    required int balance,
    Money? creditLimit,
  }) async {
    ledgerPort.accounts['credit-1'] = CreditLedgerAccountSnapshot(
      id: 'credit-1',
      balance: Money(minorUnits: balance),
      isArchived: false,
    );
    await creditAccounts.insert(
      CreditLiabilityAccountDraft(
        id: 'credit-ext-1',
        accountId: 'credit-1',
        kind: credit.CreditLiabilityAccountKind.credit,
        creditLimit: creditLimit,
        billingDay: 5,
        repaymentDay: 25,
        billingDayToNext: true,
      ),
    );
  }

  Future<({String contractId, List<String> scheduleIds})> seedContract({
    required int principal,
    required List<int> schedulePrincipals,
  }) async {
    final firstDate = DateTime(2026, 7, 25);
    final contractId = ids.newId();
    await installments.saveContract(
      InstallmentContract(
        id: contractId,
        liabilityAccountId: 'credit-1',
        sourceType: credit.InstallmentSourceType.disbursement,
        disbursementAccountId: 'cash-1',
        disbursementTransactionId: 'borrow-tx',
        principal: Money(minorUnits: principal),
        totalPeriods: schedulePrincipals.length,
        borrowingDate: DateTime(2026, 6, 25),
        firstRepaymentDate: firstDate,
        lastRepaymentDate: DateTime(
          firstDate.year,
          firstDate.month + schedulePrincipals.length - 1,
          firstDate.day,
        ),
        repaymentMethod: credit.InstallmentRepaymentMethod.equalPrincipal,
        interestAccrualMethod: credit.InterestAccrualMethod.monthly,
        totalFeeMinor: 0,
        status: credit.InstallmentContractStatus.active,
        createdAt: DateTime(2026, 6, 1),
      ),
    );
    await installments
        .saveAggregate((await installments.findContract(contractId))!, [
          for (var index = 0; index < schedulePrincipals.length; index++)
            InstallmentSchedule(
              id: ids.newId(),
              contractId: contractId,
              periodNo: index + 1,
              expectedRepaymentDate: DateTime(
                firstDate.year,
                firstDate.month + index,
                firstDate.day,
              ),
              expectedPrincipal: Money(minorUnits: schedulePrincipals[index]),
              expectedInterest:
                  index == 0 ? const Money(minorUnits: 100) : Money.zero(),
              expectedFee: Money.zero(),
              status: credit.InstallmentScheduleStatus.pending,
              createdAt: DateTime(2026, 6, 1),
            ),
        ]);
    final schedules = await installments.listSchedules(contractId);
    return (
      contractId: contractId,
      scheduleIds: [for (final schedule in schedules) schedule.id],
    );
  }

  Future<void> seedBill({
    required String id,
    required credit.BillStatus status,
    required List<_BillItemSeed> items,
    credit.BillPeriod? period,
  }) async {
    await bills.saveBill(
      Bill(
        id: id,
        accountId: 'credit-1',
        period: period ?? credit.BillPeriod(year: 2026, month: 7),
        status: status,
        items: const [],
      ),
    );
    await bills.replaceBillItems(id, [
      for (final item in items)
        BillItem(
          id: item.id,
          billId: id,
          itemType: item.itemType,
          contractId: item.contractId,
          scheduleId: item.scheduleId,
          repaymentDate: DateTime(2026, 7, 25),
          expectedPrincipal: Money(minorUnits: item.principal),
          expectedInterest: Money.zero(),
          expectedFee: Money.zero(),
          status: item.status,
        ),
    ]);
  }

  Future<void> close() => database.close();
}

class _BillItemSeed {
  const _BillItemSeed._({
    required this.id,
    required this.itemType,
    required this.principal,
    this.status = credit.BillItemStatus.pending,
    this.contractId,
    this.scheduleId,
  });

  factory _BillItemSeed.consumption({
    required String id,
    required int principal,
    credit.BillItemStatus status = credit.BillItemStatus.pending,
  }) {
    return _BillItemSeed._(
      id: id,
      itemType: credit.BillItemType.consumption,
      principal: principal,
      status: status,
    );
  }

  factory _BillItemSeed.installment({
    required String id,
    required int principal,
    required String contractId,
    required String scheduleId,
    credit.BillItemStatus status = credit.BillItemStatus.pending,
  }) {
    return _BillItemSeed._(
      id: id,
      itemType: credit.BillItemType.installment,
      principal: principal,
      contractId: contractId,
      scheduleId: scheduleId,
      status: status,
    );
  }

  final String id;
  final credit.BillItemType itemType;
  final int principal;
  final credit.BillItemStatus status;
  final String? contractId;
  final String? scheduleId;
}

class _FakeCreditLedgerPort implements CreditLedgerPort {
  final accounts = <String, CreditLedgerAccountSnapshot>{};

  @override
  Future<CreditLedgerAccountSnapshot?> findAccount(String accountId) async {
    return accounts[accountId];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
