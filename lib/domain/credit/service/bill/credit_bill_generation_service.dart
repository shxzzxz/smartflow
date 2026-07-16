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

class CreditBillGenerationResult {
  const CreditBillGenerationResult({required this.scheduleStatuses});

  static const empty = CreditBillGenerationResult(scheduleStatuses: {});

  final Map<String, BillItemStatus> scheduleStatuses;

  CreditBillGenerationResult merge(CreditBillGenerationResult other) {
    if (scheduleStatuses.isEmpty) return other;
    if (other.scheduleStatuses.isEmpty) return this;
    return CreditBillGenerationResult(
      scheduleStatuses: {...scheduleStatuses, ...other.scheduleStatuses},
    );
  }
}

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

  Future<CreditBillGenerationResult> generateDueBillsForAccount({
    required CreditLiabilityAccount account,
    required DateTime now,
  }) async {
    return switch (account.kind) {
      CreditLiabilityAccountKind.credit => await _generateCreditBills(
        account,
        _dateOnly(now),
      ),
      CreditLiabilityAccountKind.loan => await _generateCurrentLoanBill(
        account,
        _dateOnly(now),
      ),
    };
  }

  Future<CreditBillGenerationResult> generateBillForPeriod({
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
      return CreditBillGenerationResult.empty;
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
        return _refreshBill(bill);
      case CreditLiabilityAccountKind.loan:
        final bill = await _saveEmptyBill(
          accountId: account.accountId,
          period: period,
          status: BillStatus.billed,
        );
        return _refreshBill(bill);
    }
  }

  Future<CreditBillGenerationResult> refreshBill(String billId) async {
    final bill = await _bills.findBill(billId);
    if (bill == null) {
      throw BusinessException(
        CreditErrorCode.billNotFound,
        message: 'Bill does not exist.',
      );
    }
    return _refreshBill(bill);
  }

  Future<CreditBillGenerationResult> refreshDisplayedBillsForAccount({
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
    var result = CreditBillGenerationResult.empty;
    for (final period in periods) {
      final bill = await _bills.findByAccountAndPeriod(
        account.accountId,
        period,
      );
      if (bill == null || !_shouldRefreshWhenDisplayed(account, bill)) {
        continue;
      }
      result = result.merge(await _refreshBill(bill));
    }
    return result;
  }

  Future<CreditBillGenerationResult> _generateCreditBills(
    CreditLiabilityAccount account,
    DateTime now,
  ) async {
    var result = CreditBillGenerationResult.empty;
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
      result = result.merge(await _refreshBill(billed));
    } else if (billed.status == BillStatus.open) {
      result = result.merge(await _refreshBill(billed, freezeOpenBill: true));
    }

    final current = await _bills.findByAccountAndPeriod(
      account.accountId,
      currentPeriod,
    );
    if (current != null) return result;
    final opened = await _saveEmptyBill(
      accountId: account.accountId,
      period: currentPeriod,
      status: BillStatus.open,
      window: account.nextCreditBillWindow(
        currentPeriod,
        previousWindow: billed.window,
      ),
    );
    return result.merge(await _refreshBill(opened));
  }

  Future<CreditBillGenerationResult> _generateCurrentLoanBill(
    CreditLiabilityAccount account,
    DateTime now,
  ) async {
    final period = BillPeriod.fromDate(now);
    if (await _bills.findByAccountAndPeriod(account.accountId, period) !=
        null) {
      return CreditBillGenerationResult.empty;
    }
    final bill = await _saveEmptyBill(
      accountId: account.accountId,
      period: period,
      status: BillStatus.billed,
    );
    return _refreshBill(bill);
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

  Future<CreditBillGenerationResult> _refreshBill(
    Bill bill, {
    bool freezeOpenBill = false,
  }) async {
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
    await _bills.updateBill(bill);
    return CreditBillGenerationResult(
      scheduleStatuses: {
        for (final item in sourceItems)
          if (item.scheduleId != null) item.scheduleId!: item.status,
      },
    );
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
          expectedInterestMinor: 0,
          expectedFeeMinor: 0,
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
        expectedInterestMinor: schedule.expectedInterest.minorUnits,
        expectedFeeMinor: schedule.expectedFee.minorUnits,
        allocated: allocated,
      ),
      createdAt: existing?.createdAt,
    );
  }

  BillItemStatus _statusFor({
    required String itemId,
    required int expectedPrincipalMinor,
    required int expectedInterestMinor,
    required int expectedFeeMinor,
    required Map<String, RepaymentAmountBreakdown> allocated,
  }) {
    return _judgement.judgeBillItem(
      expectedPrincipalMinor: expectedPrincipalMinor,
      allocatedPrincipalMinor: allocated[itemId]?.principal.minorUnits ?? 0,
      hasAllocation: allocated.containsKey(itemId),
      hasExpectedRepayment:
          expectedPrincipalMinor != 0 ||
          expectedInterestMinor != 0 ||
          expectedFeeMinor != 0,
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
