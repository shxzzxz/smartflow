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
import 'package:smartflow/domain/credit/valobj/credit_account_enums.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_amount_breakdown.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

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
  }) : _creditAccounts = creditAccounts,
       _installments = installments,
       _repayments = repayments,
       _bills = bills,
       _suppressions = suppressions,
       _billSources = billSources,
       _idGenerator = idGenerator,
       _judgement = judgement;

  final CreditAccountRepository _creditAccounts;
  final InstallmentRepository _installments;
  final RepaymentRepository _repayments;
  final BillRepository _bills;
  final BillGenerationSuppressionRepository _suppressions;
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
    final existing = await _bills.findByAccountAndPeriod(
      account.accountId,
      period,
    );
    if (existing != null) {
      await _suppressions.clear(account.accountId, period);
      return _refreshBill(existing);
    }

    await _suppressions.clear(account.accountId, period);

    switch (account.kind) {
      case CreditLiabilityAccountKind.credit:
        final status = period == currentPeriod
            ? BillStatus.open
            : BillStatus.billed;
        final bill = await _saveEmptyBill(
          accountId: account.accountId,
          period: period,
          status: status,
          // Kept only for legacy in-memory callers. Persistence no longer
          // maps this compatibility value; item windows are authoritative.
          window: await _legacyWindowForPeriod(account, period),
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
      if (bill == null || !_shouldRefreshWhenDisplayed(bill)) {
        continue;
      }
      result = result.merge(await _refreshBill(bill));
    }
    return result;
  }

  /// 删除账单：仅允许没有任何还款记录的账单。
  ///
  /// 账单明细是来源投影，删除账单不会影响合同、还款计划或账务交易。
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
    await _refreshBill(bill, preserveConsumptionWindow: true);
  }

  /// 信用账户周期驱动生成：**不补建**历史账单。
  ///
  /// 迟到执行时会冻结现存且已过有效消费窗口的 OPEN 账单。缺失周期不补建；当上一期
  /// 缺失时，当前 OPEN 账单按账户参数重新起算，遗漏消费留在未归属欠款。
  Future<CreditBillGenerationResult> _generateCreditBills(
    CreditLiabilityAccount account,
    DateTime now,
  ) async {
    var result = CreditBillGenerationResult.empty;
    final currentPeriod = account.creditPeriodForDate(now);
    final bills = await _bills.listBillsByAccount(account.accountId);
    for (final bill in bills) {
      if (bill.status != BillStatus.open) continue;
      final interval = await _consumptionInterval(
        account,
        bill,
        bill.items
            .where((item) => item.itemType == BillItemType.consumption)
            .firstOrNull,
      );
      if (now.isBefore(interval.endInclusive.add(const Duration(days: 1)))) {
        continue;
      }
      result = result.merge(
        await _refreshBill(
          bill,
          freezeOpenBill: true,
          preserveConsumptionWindow: true,
        ),
      );
    }

    final current = await _bills.findByAccountAndPeriod(
      account.accountId,
      currentPeriod,
    );
    if (current != null) return result;
    if (await _suppressions.isSuppressed(account.accountId, currentPeriod)) {
      return result;
    }
    final opened = await _saveEmptyBill(
      accountId: account.accountId,
      period: currentPeriod,
      status: BillStatus.open,
      window: await _legacyWindowForPeriod(account, currentPeriod),
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
    if (await _suppressions.isSuppressed(account.accountId, period)) {
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
    bool preserveConsumptionWindow = false,
  }) async {
    final account = await _creditAccounts.findByAccountId(bill.accountId);
    if (account == null) {
      throw BusinessException(CreditErrorCode.accountNotFound);
    }
    final sourceItems = switch (account.kind) {
      CreditLiabilityAccountKind.credit => await _buildCreditItems(
        account,
        bill,
        preserveConsumptionWindow: preserveConsumptionWindow,
      ),
      CreditLiabilityAccountKind.loan => await _buildLoanItems(account, bill),
    };
    if (bill.status == BillStatus.open && !freezeOpenBill) {
      bill.refreshOpenProjection(sourceItems: sourceItems);
    } else if (bill.status == BillStatus.open) {
      bill.freezeAsBilled(sourceItems: sourceItems);
    } else {
      bill.synchronizeBilledItems(sourceItems);
    }
    // freezeAsBilled mutates consumption billingState. Persist the projected
    // items only after the aggregate lifecycle transition so the stored item
    // state cannot remain open on a billed bill.
    await _bills.replaceBillItems(bill.id, bill.items);
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
    Bill bill, {
    bool preserveConsumptionWindow = false,
  }) async {
    final schedules = await _schedulesForPeriod(
      accountId: account.accountId,
      period: bill.period,
    );
    final existingConsumption = bill.items
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
    final interval = await _consumptionInterval(
      account,
      bill,
      existingConsumption,
      preserveExisting: preserveConsumptionWindow,
    );
    final repaymentDate =
        bill.status == BillStatus.open || existingConsumption == null
        ? account.repaymentDateForCreditPeriod(bill.period)
        : existingConsumption.repaymentDate;
    final consumptionMinor = await _billSources.netConsumptionMinor(
      accountId: account.accountId,
      startInclusive: interval.startInclusive,
      endExclusive: interval.endInclusive.add(const Duration(days: 1)),
    );
    final consumptionId = existingConsumption?.id ?? _idGenerator.newId();
    final items = <BillItem>[];
    if (bill.status == BillStatus.open ||
        consumptionMinor > 0 ||
        existingConsumption != null ||
        schedules.isEmpty) {
      items.add(
        BillItem(
          id: consumptionId,
          billId: bill.id,
          itemType: BillItemType.consumption,
          billingState: bill.status == BillStatus.open
              ? BillItemBillingState.open
              : BillItemBillingState.billed,
          startInclusive: interval.startInclusive,
          endInclusive: interval.endInclusive,
          repaymentDate: repaymentDate,
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
      );
    }
    items.addAll([
      for (final (:contract, :schedule) in schedules)
        _itemForSchedule(
          billId: bill.id,
          contract: contract,
          schedule: schedule,
          existing: existingByScheduleId[schedule.id],
          allocated: allocated,
        ),
    ]);
    return items;
  }

  Future<List<BillItem>> _buildLoanItems(
    CreditLiabilityAccount account,
    Bill bill,
  ) async {
    final schedules = await _schedulesForPeriod(
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
          existing: existingByScheduleId[schedule.id],
          allocated: allocated,
        ),
    ];
  }

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

  Future<ConsumptionWindow> _consumptionInterval(
    CreditLiabilityAccount account,
    Bill bill,
    BillItem? existingConsumption, {
    bool preserveExisting = false,
  }) async {
    final existingStart = existingConsumption?.startInclusive;
    final existingEnd = existingConsumption?.endInclusive;
    if ((bill.status != BillStatus.open || preserveExisting) &&
        existingStart != null &&
        existingEnd != null) {
      return ConsumptionWindow(
        startInclusive: existingStart,
        endInclusive: existingEnd,
      );
    }
    final fallback = account.consumptionWindowForPeriod(bill.period);
    final previous = await _bills.findByAccountAndPeriod(
      bill.accountId,
      bill.period.previous(),
    );
    final next = await _bills.findByAccountAndPeriod(
      bill.accountId,
      bill.period.next(),
    );
    final previousConsumption = previous?.items
        .where((item) => item.itemType == BillItemType.consumption)
        .firstOrNull;
    final nextConsumption = next?.items
        .where((item) => item.itemType == BillItemType.consumption)
        .firstOrNull;
    var start = fallback.startInclusive;
    var end = fallback.endInclusive;
    if (previousConsumption?.endInclusive case final previousEnd?) {
      start = previousEnd.add(const Duration(days: 1));
    }
    if (nextConsumption?.startInclusive case final nextStart?) {
      end = nextStart.subtract(const Duration(days: 1));
    }
    if (start.isAfter(end)) {
      return fallback;
    }
    return ConsumptionWindow(startInclusive: start, endInclusive: end);
  }

  Future<List<({InstallmentContract contract, InstallmentSchedule schedule})>>
  _schedulesForPeriod({
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

  bool _shouldRefreshWhenDisplayed(Bill bill) {
    return bill.status == BillStatus.open;
  }

  Future<BillWindow> _legacyWindowForPeriod(
    CreditLiabilityAccount account,
    BillPeriod period,
  ) async {
    final base = account.nextCreditBillWindow(period);
    final previous = await _bills.findByAccountAndPeriod(
      account.accountId,
      period.previous(),
    );
    final previousConsumption = previous?.items
        .where((item) => item.itemType == BillItemType.consumption)
        .firstOrNull;
    final start =
        previousConsumption?.endInclusive?.add(const Duration(days: 1)) ??
        base.startDate;
    return BillWindow(
      period: period,
      startDate: start,
      billingDate: base.billingDate,
      repaymentDate: base.repaymentDate,
    );
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
