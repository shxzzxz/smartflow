import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/entity/credit_liability_account.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/credit_account_repository.dart';
import 'package:smartflow/domain/credit/port/credit_bill_source_repository.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/bill_period.dart';
import 'package:smartflow/domain/credit/valobj/bill_window.dart';
import 'package:smartflow/domain/credit/valobj/credit_account_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';

abstract interface class CreditBillGenerationService {
  Future<void> generateDueBills({required DateTime now});

  Future<void> generateDueBillsForAccount({
    required String accountId,
    required DateTime now,
  });
}

class CreditBillGenerationServiceImpl implements CreditBillGenerationService {
  const CreditBillGenerationServiceImpl({
    required CreditAccountRepository creditAccounts,
    required AccountRepository ledgerAccounts,
    required InstallmentRepository installments,
    required BillRepository bills,
    required CreditBillSourceRepository billSources,
    required TransactionRunner transactionRunner,
    required IdGenerator idGenerator,
  }) : _creditAccounts = creditAccounts,
       _ledgerAccounts = ledgerAccounts,
       _installments = installments,
       _bills = bills,
       _billSources = billSources,
       _runner = transactionRunner,
       _idGenerator = idGenerator;

  final CreditAccountRepository _creditAccounts;
  final AccountRepository _ledgerAccounts;
  final InstallmentRepository _installments;
  final BillRepository _bills;
  final CreditBillSourceRepository _billSources;
  final TransactionRunner _runner;
  final IdGenerator _idGenerator;

  @override
  Future<void> generateDueBills({required DateTime now}) async {
    final accounts = await _creditAccounts.listAll();
    for (final account in accounts) {
      await generateDueBillsForAccount(accountId: account.accountId, now: now);
    }
  }

  @override
  Future<void> generateDueBillsForAccount({
    required String accountId,
    required DateTime now,
  }) async {
    final creditAccount = await _creditAccounts.findByAccountId(accountId);
    if (creditAccount == null) return;
    await _runner.run<void>(() async {
      final ledgerAccount = await _ledgerAccounts.findById(accountId);
      if (ledgerAccount == null || ledgerAccount.isArchived) return;
      switch (creditAccount.kind) {
        case CreditLiabilityAccountKind.credit:
          await _generateCreditBills(creditAccount, _dateOnly(now));
        case CreditLiabilityAccountKind.loan:
          await _generateLoanBills(creditAccount, _dateOnly(now));
      }
    });
  }

  Future<void> _generateCreditBills(
    CreditLiabilityAccount account,
    DateTime now,
  ) async {
    final billingDay = account.billingDay;
    final repaymentDay = account.repaymentDay;
    final startPeriod = account.billingStartPeriod;
    if (billingDay == null || repaymentDay == null || startPeriod == null) {
      return;
    }

    final currentPeriod = _creditPeriodForDate(
      now,
      billingDay: billingDay,
      billingDayToNext: account.billingDayToNext,
    );
    var period = startPeriod;
    while (period.compareTo(currentPeriod) <= 0) {
      final window = await _creditWindowFor(
        account: account,
        period: period,
        billingDay: billingDay,
        repaymentDay: repaymentDay,
      );
      final baseStatus =
          period == currentPeriod ? BillStatus.open : BillStatus.billed;
      await _upsertCreditBill(account, window, baseStatus);
      period = period.next();
    }
  }

  Future<void> _upsertCreditBill(
    CreditLiabilityAccount account,
    BillWindow window,
    BillStatus baseStatus,
  ) async {
    final existing = await _bills.findByAccountAndPeriod(
      account.accountId,
      window.period,
    );
    final shouldRefreshItems =
        existing == null ||
        baseStatus == BillStatus.open ||
        existing.status == BillStatus.open;

    var bill =
        existing ??
        await _bills.saveBill(
          Bill(
            id: _idGenerator.newId(),
            accountId: account.accountId,
            period: window.period,
            window: window,
            status: baseStatus,
            items: const [],
          ),
        );

    if (existing != null &&
        (existing.status != baseStatus || existing.window != window)) {
      bill = existing.copyWith(window: window, status: baseStatus);
      await _bills.updateBill(bill);
    }

    if (!shouldRefreshItems) return;

    final items = await _buildCreditItems(account, bill, window);
    final status = _projectBillStatus(baseStatus, items);
    await _bills.upsertBillItems(bill.id, items);
    await _bills.updateBill(bill.copyWith(window: window, status: status));
  }

  Future<List<BillItem>> _buildCreditItems(
    CreditLiabilityAccount account,
    Bill bill,
    BillWindow window,
  ) async {
    final consumptionMinor = await _billSources.netConsumptionMinor(
      accountId: account.accountId,
      startInclusive: _effectiveCreditStart(
        window.startDate,
        account.billingDayToNext,
      ),
      endExclusive: _effectiveCreditEnd(
        window.billingDate,
        account.billingDayToNext,
      ),
    );
    final existingConsumption =
        bill.items
            .where((item) => item.itemType == BillItemType.consumption)
            .firstOrNull;

    final items = <BillItem>[
      BillItem(
        id: existingConsumption?.id ?? _idGenerator.newId(),
        billId: bill.id,
        itemType: BillItemType.consumption,
        repaymentDate: window.repaymentDate,
        expectedPrincipal: Money(minorUnits: consumptionMinor),
        expectedInterest: Money.zero(),
        expectedFee: Money.zero(),
        status:
            consumptionMinor <= 0
                ? BillItemStatus.paid
                : BillItemStatus.pending,
        createdAt: existingConsumption?.createdAt,
      ),
    ];

    final schedules = await _creditSchedulesForBill(
      accountId: account.accountId,
      repaymentDate: window.repaymentDate,
    );
    for (final (:contract, :schedule) in schedules) {
      final existingItem = _existingScheduleItem(bill, schedule.id);
      items.add(
        _itemForSchedule(
          billId: bill.id,
          contract: contract,
          schedule: schedule,
          repaymentDate: window.repaymentDate,
          existing: existingItem,
        ),
      );
    }
    return items;
  }

  Future<List<({InstallmentContract contract, InstallmentSchedule schedule})>>
  _creditSchedulesForBill({
    required String accountId,
    required DateTime repaymentDate,
  }) async {
    final contracts = await _installments.listContractsByLiabilityAccount(
      accountId,
    );
    final result =
        <({InstallmentContract contract, InstallmentSchedule schedule})>[];
    for (final contract in contracts) {
      final schedules = await _installments.listSchedules(contract.id);
      for (final schedule in schedules) {
        if (schedule.status == InstallmentScheduleStatus.skipped) continue;
        if (!_sameMonth(schedule.expectedRepaymentDate, repaymentDate)) {
          continue;
        }
        result.add((contract: contract, schedule: schedule));
      }
    }
    return result;
  }

  Future<void> _generateLoanBills(
    CreditLiabilityAccount account,
    DateTime now,
  ) async {
    final maxPeriod = BillPeriod.fromDate(DateTime(now.year, now.month + 1));
    final contracts = await _installments.listContractsByLiabilityAccount(
      account.accountId,
    );
    final byPeriod =
        <
          BillPeriod,
          List<({InstallmentContract contract, InstallmentSchedule schedule})>
        >{};

    for (final contract in contracts) {
      final schedules = await _installments.listSchedules(contract.id);
      for (final schedule in schedules) {
        if (schedule.status == InstallmentScheduleStatus.skipped) continue;
        final period = BillPeriod.fromDate(schedule.expectedRepaymentDate);
        if (period.compareTo(maxPeriod) > 0) continue;
        byPeriod
            .putIfAbsent(
              period,
              () =>
                  <
                    ({
                      InstallmentContract contract,
                      InstallmentSchedule schedule,
                    })
                  >[],
            )
            .add((contract: contract, schedule: schedule));
      }
    }

    final periods = byPeriod.keys.toList()..sort();
    for (final period in periods) {
      final existing = await _bills.findByAccountAndPeriod(
        account.accountId,
        period,
      );
      if (existing != null && existing.status != BillStatus.open) continue;

      final baseBill =
          existing ??
          await _bills.saveBill(
            Bill(
              id: _idGenerator.newId(),
              accountId: account.accountId,
              period: period,
              status: BillStatus.billed,
              items: const [],
            ),
          );
      final items = [
        for (final (:contract, :schedule) in byPeriod[period]!)
          _itemForSchedule(
            billId: baseBill.id,
            contract: contract,
            schedule: schedule,
            repaymentDate: schedule.expectedRepaymentDate,
            existing: _existingScheduleItem(baseBill, schedule.id),
          ),
      ];
      final status = _projectBillStatus(BillStatus.billed, items);
      await _bills.upsertBillItems(baseBill.id, items);
      await _bills.updateBill(baseBill.copyWith(status: status));
    }
  }

  BillItem _itemForSchedule({
    required String billId,
    required InstallmentContract contract,
    required InstallmentSchedule schedule,
    required DateTime repaymentDate,
    required BillItem? existing,
  }) {
    return BillItem(
      id: existing?.id ?? _idGenerator.newId(),
      billId: billId,
      itemType: BillItemType.installment,
      contractId: contract.id,
      scheduleId: schedule.id,
      repaymentDate: repaymentDate,
      expectedPrincipal: schedule.expectedPrincipal,
      expectedInterest: schedule.expectedInterest,
      expectedFee: schedule.expectedFee,
      status: _statusForSchedule(schedule),
      createdAt: existing?.createdAt,
    );
  }

  BillItem? _existingScheduleItem(Bill bill, String scheduleId) {
    for (final item in bill.items) {
      if (item.scheduleId == scheduleId) return item;
    }
    return null;
  }

  BillItemStatus _statusForSchedule(InstallmentSchedule schedule) {
    return switch (schedule.status) {
      InstallmentScheduleStatus.pending => BillItemStatus.pending,
      InstallmentScheduleStatus.paid => BillItemStatus.paid,
      InstallmentScheduleStatus.skipped => BillItemStatus.skipped,
    };
  }

  BillStatus _projectBillStatus(BillStatus baseStatus, List<BillItem> items) {
    if (baseStatus == BillStatus.open) return BillStatus.open;
    return items.any((item) => item.status == BillItemStatus.pending)
        ? BillStatus.billed
        : BillStatus.settled;
  }

  Future<BillWindow> _creditWindowFor({
    required CreditLiabilityAccount account,
    required BillPeriod period,
    required int billingDay,
    required int repaymentDay,
  }) async {
    final previousPeriod = period.previous();
    final previousBill = await _bills.findByAccountAndPeriod(
      account.accountId,
      previousPeriod,
    );
    final billingDate = DateTime(period.year, period.month, billingDay);
    final startDate =
        previousBill?.window?.billingDate ??
        DateTime(previousPeriod.year, previousPeriod.month, billingDay);
    final repaymentPeriod = repaymentDay > billingDay ? period : period.next();
    final repaymentDate = DateTime(
      repaymentPeriod.year,
      repaymentPeriod.month,
      repaymentDay,
    );
    return BillWindow(
      period: period,
      startDate: startDate,
      billingDate: billingDate,
      repaymentDate: repaymentDate,
    );
  }

  BillPeriod _creditPeriodForDate(
    DateTime date, {
    required int billingDay,
    required bool billingDayToNext,
  }) {
    final day = date.day;
    if (day < billingDay || (!billingDayToNext && day == billingDay)) {
      return BillPeriod(year: date.year, month: date.month);
    }
    final next = DateTime(date.year, date.month + 1);
    return BillPeriod(year: next.year, month: next.month);
  }

  DateTime _effectiveCreditStart(DateTime startDate, bool billingDayToNext) {
    return billingDayToNext
        ? startDate
        : startDate.add(const Duration(days: 1));
  }

  DateTime _effectiveCreditEnd(DateTime billingDate, bool billingDayToNext) {
    return billingDayToNext
        ? billingDate
        : billingDate.add(const Duration(days: 1));
  }

  bool _sameMonth(DateTime left, DateTime right) {
    return left.year == right.year && left.month == right.month;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
