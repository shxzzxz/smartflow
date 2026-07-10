import 'package:smartflow/core/error/app_exception.dart';
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
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/service/settlement/settlement_judgement_service.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/bill_period.dart';
import 'package:smartflow/domain/credit/valobj/bill_window.dart';
import 'package:smartflow/domain/credit/valobj/credit_account_enums.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_amount_breakdown.dart';

class CreditBillGenerationService {
  const CreditBillGenerationService({
    required CreditAccountRepository creditAccounts,
    required InstallmentRepository installments,
    required RepaymentRepository repayments,
    required BillRepository bills,
    required CreditBillSourceRepository billSources,
    required IdGenerator idGenerator,
    SettlementJudgementService judgement = const SettlementJudgementService(),
  }) : _creditAccounts = creditAccounts,
       _installments = installments,
       _repayments = repayments,
       _bills = bills,
       _billSources = billSources,
       _idGenerator = idGenerator,
       _judgement = judgement;

  final CreditAccountRepository _creditAccounts;
  final InstallmentRepository _installments;
  final RepaymentRepository _repayments;
  final BillRepository _bills;
  final CreditBillSourceRepository _billSources;
  final IdGenerator _idGenerator;
  final SettlementJudgementService _judgement;

  Future<void> generateDueBillsForAccount({
    required CreditLiabilityAccount account,
    required DateTime now,
  }) async {
    switch (account.kind) {
      case CreditLiabilityAccountKind.credit:
        await _generateCreditBills(account, _dateOnly(now));
      case CreditLiabilityAccountKind.loan:
        await _generateCurrentLoanBill(account, _dateOnly(now));
    }
  }

  Future<void> generateBillForPeriod({
    required CreditLiabilityAccount account,
    required BillPeriod period,
    required DateTime now,
  }) async {
    final currentPeriod = switch (account.kind) {
      CreditLiabilityAccountKind.credit => account.creditPeriodForDate(now),
      CreditLiabilityAccountKind.loan => BillPeriod.fromDate(now),
    };
    if (period.compareTo(currentPeriod) > 0) {
      throw BusinessException(
        CreditErrorCode.billInvalidCommand,
        message: 'Future bill periods cannot be generated manually.',
      );
    }
    if (await _bills.findByAccountAndPeriod(account.accountId, period) !=
        null) {
      return;
    }

    switch (account.kind) {
      case CreditLiabilityAccountKind.credit:
        final previous = await _bills.findByAccountAndPeriod(
          account.accountId,
          period.previous(),
        );
        final window = account.nextCreditBillWindow(
          period,
          previousWindow: previous?.window,
        );
        final status =
            period == currentPeriod ? BillStatus.open : BillStatus.billed;
        final bill = await _saveEmptyBill(
          accountId: account.accountId,
          period: period,
          status: status,
          window: window,
        );
        await _refreshBill(bill);
      case CreditLiabilityAccountKind.loan:
        final bill = await _saveEmptyBill(
          accountId: account.accountId,
          period: period,
          status: BillStatus.billed,
        );
        await _refreshBill(bill);
    }
  }

  Future<void> refreshBill(String billId) async {
    final bill = await _bills.findBill(billId);
    if (bill == null) {
      throw BusinessException(
        CreditErrorCode.billNotFound,
        message: 'Bill does not exist.',
      );
    }
    await _refreshBill(bill);
  }

  Future<void> refreshDisplayedBillsForAccount({
    required CreditLiabilityAccount account,
    required DateTime now,
  }) async {
    final periods = switch (account.kind) {
      CreditLiabilityAccountKind.credit => [
        account.creditPeriodForDate(now).previous(),
        account.creditPeriodForDate(now),
      ],
      CreditLiabilityAccountKind.loan => [BillPeriod.fromDate(now)],
    };
    for (final period in periods) {
      final bill = await _bills.findByAccountAndPeriod(
        account.accountId,
        period,
      );
      if (bill == null || !_shouldRefreshWhenDisplayed(account, bill)) {
        continue;
      }
      await _refreshBill(bill);
    }
  }

  Future<void> _generateCreditBills(
    CreditLiabilityAccount account,
    DateTime now,
  ) async {
    final currentPeriod = account.creditPeriodForDate(now);
    final billedPeriod = currentPeriod.previous();
    var billed = await _bills.findByAccountAndPeriod(
      account.accountId,
      billedPeriod,
    );
    if (billed == null) {
      final prior = await _bills.findByAccountAndPeriod(
        account.accountId,
        billedPeriod.previous(),
      );
      billed = await _saveEmptyBill(
        accountId: account.accountId,
        period: billedPeriod,
        status: BillStatus.billed,
        window: account.nextCreditBillWindow(
          billedPeriod,
          previousWindow: prior?.window,
        ),
      );
      await _refreshBill(billed);
    } else if (billed.status == BillStatus.open) {
      await _refreshBill(billed, freezeOpenBill: true);
    }

    final current = await _bills.findByAccountAndPeriod(
      account.accountId,
      currentPeriod,
    );
    if (current != null) return;
    final opened = await _saveEmptyBill(
      accountId: account.accountId,
      period: currentPeriod,
      status: BillStatus.open,
      window: account.nextCreditBillWindow(
        currentPeriod,
        previousWindow: billed.window,
      ),
    );
    await _refreshBill(opened);
  }

  Future<void> _generateCurrentLoanBill(
    CreditLiabilityAccount account,
    DateTime now,
  ) async {
    final period = BillPeriod.fromDate(now);
    if (await _bills.findByAccountAndPeriod(account.accountId, period) !=
        null) {
      return;
    }
    final bill = await _saveEmptyBill(
      accountId: account.accountId,
      period: period,
      status: BillStatus.billed,
    );
    await _refreshBill(bill);
  }

  Future<Bill> _saveEmptyBill({
    required String accountId,
    required BillPeriod period,
    required BillStatus status,
    BillWindow? window,
  }) {
    return _bills.saveBill(
      Bill(
        id: _idGenerator.newId(),
        accountId: accountId,
        period: period,
        window: window,
        status: status,
        items: const [],
      ),
    );
  }

  Future<void> _refreshBill(Bill bill, {bool freezeOpenBill = false}) async {
    final account = await _creditAccounts.findByAccountId(bill.accountId);
    if (account == null) {
      throw BusinessException(CreditErrorCode.accountNotFound);
    }
    final sourceItems = switch (account.kind) {
      CreditLiabilityAccountKind.credit =>
        bill.window == null
            ? bill.items
            : await _buildCreditItems(account, bill, bill.window!),
      CreditLiabilityAccountKind.loan => await _buildLoanItems(account, bill),
    };
    await _bills.replaceBillItems(bill.id, sourceItems);
    if (bill.status == BillStatus.open && !freezeOpenBill) {
      bill.refreshOpenProjection(
        window: bill.window!,
        sourceItems: sourceItems,
      );
    } else if (bill.status == BillStatus.open) {
      bill.freezeAsBilled(window: bill.window, sourceItems: sourceItems);
    } else {
      bill.synchronizeBilledItems(sourceItems);
    }
    await _refreshInstallmentStatusesFromItems(sourceItems);
    await _bills.updateBill(bill);
  }

  Future<List<BillItem>> _buildCreditItems(
    CreditLiabilityAccount account,
    Bill bill,
    BillWindow window,
  ) async {
    final schedules = await _creditSchedulesForBill(
      accountId: account.accountId,
      repaymentDate: window.repaymentDate,
    );
    final existingConsumption =
        bill.items
            .where((item) => item.itemType == BillItemType.consumption)
            .firstOrNull;
    final existingByScheduleId = {
      for (final item in bill.items)
        if (item.scheduleId != null) item.scheduleId!: item,
    };
    final existingIds = <String>{
      if (existingConsumption != null) existingConsumption.id,
      for (final entry in schedules)
        if (existingByScheduleId[entry.schedule.id] != null)
          existingByScheduleId[entry.schedule.id]!.id,
    };
    final allocated = await _repayments.aggregateItemsByBillItemIds(
      existingIds,
    );
    final consumptionMinor = await _billSources.netConsumptionMinor(
      accountId: account.accountId,
      startInclusive: account.effectiveCreditWindowStart(window),
      endExclusive: account.effectiveCreditWindowEnd(window),
    );
    final consumptionId = existingConsumption?.id ?? _idGenerator.newId();
    return [
      BillItem(
        id: consumptionId,
        billId: bill.id,
        itemType: BillItemType.consumption,
        repaymentDate: window.repaymentDate,
        expectedPrincipal: Money(minorUnits: consumptionMinor),
        expectedInterest: Money.zero(),
        expectedFee: Money.zero(),
        status: _statusFor(
          itemId: consumptionId,
          expectedPrincipalMinor: consumptionMinor,
          allocated: allocated,
        ),
        createdAt: existingConsumption?.createdAt,
      ),
      for (final (:contract, :schedule) in schedules)
        _itemForSchedule(
          billId: bill.id,
          contract: contract,
          schedule: schedule,
          repaymentDate: window.repaymentDate,
          existing: existingByScheduleId[schedule.id],
          allocated: allocated,
        ),
    ];
  }

  Future<List<BillItem>> _buildLoanItems(
    CreditLiabilityAccount account,
    Bill bill,
  ) async {
    final schedules = await _loanSchedulesForPeriod(
      accountId: account.accountId,
      period: bill.period,
    );
    final existingByScheduleId = {
      for (final item in bill.items)
        if (item.scheduleId != null) item.scheduleId!: item,
    };
    final allocated = await _repayments.aggregateItemsByBillItemIds([
      for (final entry in schedules)
        if (existingByScheduleId[entry.schedule.id] != null)
          existingByScheduleId[entry.schedule.id]!.id,
    ]);
    return [
      for (final (:contract, :schedule) in schedules)
        _itemForSchedule(
          billId: bill.id,
          contract: contract,
          schedule: schedule,
          repaymentDate: schedule.expectedRepaymentDate,
          existing: existingByScheduleId[schedule.id],
          allocated: allocated,
        ),
    ];
  }

  BillItem _itemForSchedule({
    required String billId,
    required InstallmentContract contract,
    required InstallmentSchedule schedule,
    required DateTime repaymentDate,
    required BillItem? existing,
    required Map<String, RepaymentAmountBreakdown> allocated,
  }) {
    final itemId = existing?.id ?? _idGenerator.newId();
    return BillItem(
      id: itemId,
      billId: billId,
      itemType: BillItemType.installment,
      contractId: contract.id,
      scheduleId: schedule.id,
      repaymentDate: repaymentDate,
      expectedPrincipal: schedule.expectedPrincipal,
      expectedInterest: schedule.expectedInterest,
      expectedFee: schedule.expectedFee,
      status: _statusFor(
        itemId: itemId,
        expectedPrincipalMinor: schedule.expectedPrincipal.minorUnits,
        allocated: allocated,
      ),
      createdAt: existing?.createdAt,
    );
  }

  BillItemStatus _statusFor({
    required String itemId,
    required int expectedPrincipalMinor,
    required Map<String, RepaymentAmountBreakdown> allocated,
  }) {
    return _judgement.judgeBillItem(
      expectedPrincipalMinor: expectedPrincipalMinor,
      allocatedPrincipalMinor: allocated[itemId]?.principal.minorUnits ?? 0,
      hasAllocation: allocated.containsKey(itemId),
    );
  }

  Future<List<({InstallmentContract contract, InstallmentSchedule schedule})>>
  _creditSchedulesForBill({
    required String accountId,
    required DateTime repaymentDate,
  }) async {
    final result =
        <({InstallmentContract contract, InstallmentSchedule schedule})>[];
    for (final contract in await _installments.listContractsByLiabilityAccount(
      accountId,
    )) {
      for (final schedule in await _installments.listSchedules(contract.id)) {
        if (schedule.status == InstallmentScheduleStatus.skipped ||
            !_sameMonth(schedule.expectedRepaymentDate, repaymentDate)) {
          continue;
        }
        result.add((contract: contract, schedule: schedule));
      }
    }
    return result;
  }

  Future<List<({InstallmentContract contract, InstallmentSchedule schedule})>>
  _loanSchedulesForPeriod({
    required String accountId,
    required BillPeriod period,
  }) async {
    final result =
        <({InstallmentContract contract, InstallmentSchedule schedule})>[];
    for (final contract in await _installments.listContractsByLiabilityAccount(
      accountId,
    )) {
      for (final schedule in await _installments.listSchedules(contract.id)) {
        if (schedule.status == InstallmentScheduleStatus.skipped ||
            BillPeriod.fromDate(schedule.expectedRepaymentDate) != period) {
          continue;
        }
        result.add((contract: contract, schedule: schedule));
      }
    }
    return result;
  }

  Future<void> _refreshInstallmentStatusesFromItems(
    List<BillItem> items,
  ) async {
    final touchedContractIds = <String>{};
    for (final item in items) {
      final scheduleId = item.scheduleId;
      if (scheduleId == null) continue;
      final schedule = await _installments.findSchedule(scheduleId);
      if (schedule == null) continue;
      final nextStatus = _judgement.projectScheduleStatus(item.status);
      if (nextStatus != schedule.status) {
        await _installments.updateSchedule(
          schedule.id,
          InstallmentSchedulePatch(status: nextStatus),
        );
      }
      touchedContractIds.add(schedule.contractId);
    }
    for (final contractId in touchedContractIds) {
      final contract = await _installments.findContract(contractId);
      if (contract == null) continue;
      final schedules = await _installments.listSchedules(contractId);
      final nextStatus = _judgement.projectContractStatus(
        current: contract.status,
        schedules: schedules,
      );
      if (nextStatus != contract.status) {
        await _installments.updateContractStatus(contractId, nextStatus);
      }
    }
  }

  bool _shouldRefreshWhenDisplayed(CreditLiabilityAccount account, Bill bill) {
    return switch (account.kind) {
      CreditLiabilityAccountKind.credit =>
        bill.status == BillStatus.open || bill.status == BillStatus.billed,
      CreditLiabilityAccountKind.loan => bill.status == BillStatus.billed,
    };
  }

  bool _sameMonth(DateTime left, DateTime right) {
    return left.year == right.year && left.month == right.month;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
