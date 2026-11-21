import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/entity/credit_liability_account.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/bill_generation_suppression_repository.dart';
import 'package:smartflow/domain/credit/port/credit_account_repository.dart';
import 'package:smartflow/domain/credit/port/credit_bill_source_repository.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/service/settlement/settlement_judgement_service.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/bill_period.dart';
import 'package:smartflow/domain/credit/valobj/bill_window.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_amount_breakdown.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

import 'bill_generation_strategy.dart';

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
    required BillGenerationSuppressionRepository suppressions,
    required CreditBillSourceRepository billSources,
    required IdGenerator idGenerator,
    SettlementJudgementService judgement = const SettlementJudgementService(),
    DateTime Function()? now,
  }) : _creditAccounts = creditAccounts,
       _installments = installments,
       _repayments = repayments,
       _bills = bills,
       _suppressions = suppressions,
       _billSources = billSources,
       _idGenerator = idGenerator,
       _judgement = judgement,
       _now = now;

  final CreditAccountRepository _creditAccounts;
  final InstallmentRepository _installments;
  final RepaymentRepository _repayments;
  final BillRepository _bills;
  final BillGenerationSuppressionRepository _suppressions;
  final CreditBillSourceRepository _billSources;
  final IdGenerator _idGenerator;
  final SettlementJudgementService _judgement;
  final DateTime Function()? _now;

  Future<CreditBillGenerationResult> generateDueBillsForAccount({
    required CreditLiabilityAccount account,
    required DateTime now,
  }) async {
    final bills = await _bills.listBillsByAccount(account.accountId);
    final contracts = await _installments.listContractsByLiabilityAccount(
      account.accountId,
    );
    final current = _strategy(account).currentPeriod(account, now, bills);
    // Ending accumulation only advances a marker. Historical amounts are
    // recomputed solely by explicit refresh or by browsing that bill.
    for (final bill in bills) {
      if (bill.period.compareTo(current) >= 0 ||
          bill.status != BillStatus.open) {
        continue;
      }
      final windowEnded = bill.items.any(
        (item) =>
            item.itemType == BillItemType.consumption &&
            item.endInclusive != null &&
            _dateOnly(now).isAfter(item.endInclusive!),
      );
      if (!windowEnded) {
        continue;
      }
      bill.endConsumptionAccumulation();
      await _persistBill(bill);
    }
    return _maintainBills(account, now, current, bills, contracts);
  }

  Future<CreditBillGenerationResult> _maintainBills(
    CreditLiabilityAccount account,
    DateTime now,
    BillPeriod current,
    List<Bill> bills,
    List<InstallmentContract> contracts, {
    bool refreshCurrent = true,
  }) async {
    final periods = <BillPeriod>{
      current,
      for (final contract in contracts)
        if (contract.status == InstallmentContractStatus.active)
          for (final schedule in contract.schedules)
            if (hasBillObligation(schedule) &&
                BillPeriod.fromDate(
                      schedule.expectedRepaymentDate,
                    ).compareTo(current) >=
                    0)
              BillPeriod.fromDate(schedule.expectedRepaymentDate),
    }.toList()..sort();

    for (final period in periods) {
      await _ensureBill(account, period, bills);
    }
    var result = CreditBillGenerationResult.empty;
    final refreshable =
        bills
            .where(
              (bill) =>
                  bill.period.compareTo(current) >= (refreshCurrent ? 0 : 1),
            )
            .toList()
          ..sort((a, b) => a.period.compareTo(b.period));
    for (final bill in refreshable) {
      result = result.merge(
        await _projectBill(account, bill, now, current, bills, contracts),
      );
    }
    return result;
  }

  Future<Bill?> _ensureBill(
    CreditLiabilityAccount account,
    BillPeriod period,
    List<Bill> bills,
  ) async {
    final existing = bills.where((bill) => bill.period == period).firstOrNull;
    if (existing != null) return existing;
    if (await _suppressions.isSuppressed(account.accountId, period)) {
      return null;
    }
    final bill = await _bills.saveBill(
      Bill(
        id: _idGenerator.newId(),
        accountId: account.accountId,
        period: period,
        status: BillStatus.billed,
        items: const [],
      ),
    );
    bills.add(bill);
    return bill;
  }

  Future<CreditBillGenerationResult> generateBillForPeriod({
    required CreditLiabilityAccount account,
    required BillPeriod period,
    required DateTime now,
  }) async {
    await _suppressions.clear(account.accountId, period);
    final bills = await _bills.listBillsByAccount(account.accountId);
    final current = _strategy(account).currentPeriod(account, now, bills);
    final bill = (await _ensureBill(account, period, bills))!;
    final contracts = await _installments.listContractsByLiabilityAccount(
      account.accountId,
    );
    return _projectBill(account, bill, now, current, bills, contracts);
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

  Future<CreditBillGenerationResult> refreshCurrentAndFutureBillsForAccount({
    required CreditLiabilityAccount account,
    required DateTime now,
  }) async {
    final bills = await _bills.listBillsByAccount(account.accountId);
    final current = _strategy(account).currentPeriod(account, now, bills);
    final contracts = await _installments.listContractsByLiabilityAccount(
      account.accountId,
    );
    var result = CreditBillGenerationResult.empty;
    final refreshable =
        bills.where((bill) => bill.period.compareTo(current) >= 0).toList()
          ..sort((a, b) => a.period.compareTo(b.period));
    for (final bill in refreshable) {
      result = result.merge(
        await _projectBill(account, bill, now, current, bills, contracts),
      );
    }
    return result;
  }

  /// A cycle change retains the current consumption window and regenerates
  /// future projections. Creation origin grants no protection; repayments do.
  Future<CreditBillGenerationResult> rebuildFutureBills({
    required CreditLiabilityAccount previousAccount,
    required CreditLiabilityAccount account,
    required DateTime now,
  }) async {
    final bills = await _bills.listBillsByAccount(account.accountId);
    final contracts = await _installments.listContractsByLiabilityAccount(
      account.accountId,
    );
    final current = _strategy(
      previousAccount,
    ).currentPeriod(previousAccount, now, bills);
    final existingCurrent = bills
        .where((bill) => bill.period == current)
        .firstOrNull;
    final retained = await _ensureBill(previousAccount, current, bills);
    if (existingCurrent == null && retained != null) {
      await _projectBill(
        previousAccount,
        retained,
        now,
        current,
        bills,
        contracts,
      );
    }
    final future = bills
        .where((bill) => bill.period.compareTo(current) > 0)
        .toList();
    for (final bill in future) {
      final repayments = await _repayments.listByTarget(
        RepaymentTargetType.bill,
        bill.id,
      );
      if (repayments.isEmpty) {
        // Rebuilding a projection must not record a user deletion intent.
        await _bills.deleteBill(bill.id);
        bills.remove(bill);
      } else {
        for (final item in bill.items) {
          if (item.itemType == BillItemType.consumption) {
            item.startInclusive = null;
            item.endInclusive = null;
            item.billingState = BillItemBillingState.open;
          }
        }
        bill.window = null;
      }
    }
    return _maintainBills(
      account,
      now,
      current,
      bills,
      contracts,
      refreshCurrent: false,
    );
  }

  Future<void> deleteBill(String billId) async {
    final bill = await _bills.findBill(billId);
    if (bill == null) {
      throw BusinessException(CreditErrorCode.billNotFound);
    }
    final repayments = await _repayments.listByTarget(
      RepaymentTargetType.bill,
      billId,
    );
    if (repayments.isNotEmpty) {
      throw BusinessException(CreditErrorCode.billHasRepayments);
    }
    await _bills.deleteBill(billId);
    await _suppressions.suppress(bill.accountId, bill.period);
  }

  /// Legacy compatibility entry point. Consumption windows are owned by the
  /// consumption item; bill-level window edits are no longer supported.
  Future<void> updateBillWindow({
    required String billId,
    required DateTime startDate,
    required DateTime billingDate,
  }) async {
    final bill = await _bills.findBill(billId);
    if (bill == null) {
      throw BusinessException(CreditErrorCode.billNotFound);
    }
    final consumption = bill.items
        .where((item) => item.itemType == BillItemType.consumption)
        .firstOrNull;
    if (consumption == null) {
      throw BusinessException(
        CreditErrorCode.billInvalidCommand,
        message: '账单没有消费明细。',
      );
    }
    // Compatibility for in-memory callers that still construct the legacy
    // window. The persisted repository no longer reads or writes these
    // columns; the consumption item remains authoritative.
    if (bill.window case final currentWindow?) {
      if (!startDate.isBefore(billingDate) ||
          billingDate.isAfter(currentWindow.repaymentDate)) {
        throw BusinessException(CreditErrorCode.billWindowInvalid);
      }
      final previous = await _bills.findByAccountAndPeriod(
        bill.accountId,
        bill.period.previous(),
      );
      final next = await _bills.findByAccountAndPeriod(
        bill.accountId,
        bill.period.next(),
      );
      if (previous?.window case final previousWindow?
          when startDate.isBefore(previousWindow.billingDate)) {
        throw BusinessException(CreditErrorCode.billWindowOverlap);
      }
      if (next?.window case final nextWindow?
          when billingDate.isAfter(nextWindow.startDate)) {
        throw BusinessException(CreditErrorCode.billWindowOverlap);
      }
      bill.window = BillWindow(
        period: bill.period,
        startDate: startDate,
        billingDate: billingDate,
        repaymentDate: currentWindow.repaymentDate,
      );
    }
    await updateConsumptionWindow(
      billId: billId,
      billItemId: consumption.id,
      startInclusive: startDate,
      endInclusive: billingDate.subtract(const Duration(days: 1)),
    );
  }

  /// Edits the closed consumption interval carried by one consumption item.
  /// The item remains in its original bill month; moving it across months is
  /// handled by source posting dates or explicit bill generation.
  Future<void> updateConsumptionWindow({
    required String billId,
    required String billItemId,
    required DateTime startInclusive,
    required DateTime endInclusive,
  }) async {
    final bill = await _bills.findBill(billId);
    if (bill == null) {
      throw BusinessException(CreditErrorCode.billNotFound);
    }
    final item = bill.items.firstWhere(
      (candidate) => candidate.id == billItemId,
      orElse: () => throw BusinessException(CreditErrorCode.billInvalidCommand),
    );
    if (item.itemType != BillItemType.consumption ||
        startInclusive.isAfter(endInclusive) ||
        BillPeriod.fromDate(endInclusive) != bill.period) {
      throw BusinessException(
        CreditErrorCode.billWindowInvalid,
        message: '消费统计区间必须为闭区间，且结束日必须仍在原账单月份。',
      );
    }
    item.startInclusive = _dateOnly(startInclusive);
    item.endInclusive = _dateOnly(endInclusive);
    await _bills.replaceBillItems(bill.id, bill.items);
    await _refreshBill(bill);
  }

  Future<CreditBillGenerationResult> _refreshBill(Bill bill) async {
    final account = await _creditAccounts.findByAccountId(bill.accountId);
    if (account == null) {
      throw BusinessException(CreditErrorCode.accountNotFound);
    }
    final bills = await _bills.listBillsByAccount(bill.accountId);
    bills.removeWhere((candidate) => candidate.id == bill.id);
    bills.add(bill);
    final now = _dateOnly(_now?.call() ?? DateTime.now());
    final current = _strategy(account).currentPeriod(account, now, bills);
    final contracts = await _installments.listContractsByLiabilityAccount(
      bill.accountId,
    );
    return _projectBill(account, bill, now, current, bills, contracts);
  }

  Future<CreditBillGenerationResult> _projectBill(
    CreditLiabilityAccount account,
    Bill bill,
    DateTime now,
    BillPeriod current,
    List<Bill> bills,
    List<InstallmentContract> contracts,
  ) async {
    final sources = _strategy(account).sources(
      account: account,
      bill: bill,
      now: now,
      currentPeriod: current,
      bills: bills,
      contracts: contracts,
    );
    final allocated = await _repayments.aggregateItemsByBillItemIds(
      bill.items.map((item) => item.id),
    );
    final existingByScheduleId = {
      for (final item in bill.items)
        if (item.scheduleId != null) item.scheduleId!: item,
    };
    final items = <BillItem>[];
    if (sources.consumption case final source?) {
      final existing = bill.items
          .where((item) => item.itemType == BillItemType.consumption)
          .firstOrNull;
      final principal = await _billSources.netConsumptionMinor(
        accountId: account.accountId,
        startInclusive: source.window.startInclusive,
        endExclusive: source.window.endInclusive.add(const Duration(days: 1)),
      );
      final itemId = existing?.id ?? _idGenerator.newId();
      items.add(
        BillItem(
          id: itemId,
          billId: bill.id,
          itemType: BillItemType.consumption,
          billingState: source.billingState,
          startInclusive: source.window.startInclusive,
          endInclusive: source.window.endInclusive,
          repaymentDate: source.repaymentDate,
          expectedPrincipal: Money(minorUnits: principal),
          expectedInterest: Money.zero(),
          expectedFee: Money.zero(),
          status: _statusFor(
            itemId: itemId,
            expectedPrincipalMinor: principal,
            expectedInterestMinor: 0,
            expectedFeeMinor: 0,
            allocated: allocated,
          ),
          createdAt: existing?.createdAt,
        ),
      );
      bill.window ??= source.legacyWindow;
    }
    items.addAll([
      for (final (:contract, :schedule) in sources.installments)
        _itemForSchedule(
          billId: bill.id,
          contract: contract,
          schedule: schedule,
          existing: existingByScheduleId[schedule.id],
          allocated: allocated,
        ),
    ]);
    final retainedIds = items.map((item) => item.id).toSet();
    final removedIds = bill.items
        .where((item) => !retainedIds.contains(item.id))
        .map((item) => item.id)
        .toSet();
    if (removedIds.isNotEmpty) {
      for (final repayment in await _repayments.listByTarget(
        RepaymentTargetType.bill,
        bill.id,
      )) {
        if (repayment.detachBillItems(removedIds)) {
          await _repayments.updateRepayment(repayment);
        }
      }
    }
    bill.synchronizeProjection(items);
    await _persistBill(bill);
    return CreditBillGenerationResult(
      scheduleStatuses: {
        for (final item in items)
          if (item.scheduleId != null) item.scheduleId!: item.status,
      },
    );
  }

  Future<void> _persistBill(Bill bill) async {
    await _bills.replaceBillItems(bill.id, bill.items);
    await _bills.updateBill(bill);
  }

  BillGenerationStrategy _strategy(CreditLiabilityAccount account) =>
      billGenerationStrategies[account.kind]!;

  BillItem _itemForSchedule({
    required String billId,
    required InstallmentContract contract,
    required InstallmentSchedule schedule,
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
      repaymentDate: schedule.expectedRepaymentDate,
      expectedPrincipal: schedule.expectedPrincipal,
      expectedInterest: schedule.expectedInterest,
      expectedFee: schedule.expectedFee,
      billingState: BillItemBillingState.billed,
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
    final status = _judgement.judgeBillItem(
      expectedPrincipalMinor: expectedPrincipalMinor,
      allocatedPrincipalMinor: allocated[itemId]?.principal.minorUnits ?? 0,
      hasAllocation: allocated.containsKey(itemId),
      hasExpectedRepayment:
          expectedPrincipalMinor != 0 ||
          expectedInterestMinor != 0 ||
          expectedFeeMinor != 0,
    );
    final allocatedPrincipal = allocated[itemId]?.principal.minorUnits ?? 0;
    return status == BillItemStatus.paid &&
            allocatedPrincipal > expectedPrincipalMinor
        ? BillItemStatus.overpaid
        : status;
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
