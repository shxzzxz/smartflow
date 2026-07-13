import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/credit_account_repository.dart';
import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/credit_account_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_amount_breakdown.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

import 'bill_read_models.dart';

abstract interface class BillQueryService {
  Future<List<BillSummaryReadModel>> listBillsByAccount(String accountId);

  Future<BillDetailReadModel?> findBillDetail(String billId);

  Future<bool> hasUnsettledObligations(String accountId);
}

class BillQueryServiceImpl implements BillQueryService {
  const BillQueryServiceImpl({
    required BillRepository bills,
    required CreditAccountRepository creditAccounts,
    required InstallmentRepository installments,
    required RepaymentRepository repayments,
    required CreditLedgerPort ledger,
    DateTime Function()? now,
  }) : _bills = bills,
       _creditAccounts = creditAccounts,
       _installments = installments,
       _repayments = repayments,
       _ledger = ledger,
       _now = now;

  final BillRepository _bills;
  final CreditAccountRepository _creditAccounts;
  final InstallmentRepository _installments;
  final RepaymentRepository _repayments;
  final CreditLedgerPort _ledger;
  final DateTime Function()? _now;

  @override
  Future<List<BillSummaryReadModel>> listBillsByAccount(
    String accountId,
  ) async {
    final now = _currentTime();
    final bills = await _bills.listBillsByAccount(accountId);
    final allocatedByItemId = await _repayments.aggregateItemsByBillItemIds(
      bills.expand((bill) => bill.items).map((item) => item.id),
    );
    final result = <BillSummaryReadModel>[];
    for (final bill in bills) {
      result.add(
        _summaryForBill(
          bill: bill,
          now: now,
          allocatedByItemId: allocatedByItemId,
        ),
      );
    }
    return result;
  }

  @override
  Future<BillDetailReadModel?> findBillDetail(String billId) async {
    final bill = await _bills.findBill(billId);
    if (bill == null) return null;
    final now = _currentTime();
    final allocatedByItemId = await _repayments.aggregateItemsByBillItemIds(
      bill.items.map((item) => item.id),
    );
    final creditAccount = await _creditAccounts.findByAccountId(bill.accountId);
    final contracts = await _contractsById(bill.accountId);
    final repayments = await _repaymentsForBill(bill);
    final items = <BillItemReadModel>[];
    for (final item in bill.items) {
      items.add(
        _itemForBill(
          item: item,
          now: now,
          accountKind: creditAccount?.kind,
          contract: contracts[item.contractId],
          allocated:
              allocatedByItemId[item.id] ?? RepaymentAmountBreakdown.zero,
        ),
      );
    }

    return BillDetailReadModel(
      summary: _summaryForBill(
        bill: bill,
        now: now,
        allocatedByItemId: allocatedByItemId,
      ),
      items: items,
      repayments: repayments,
    );
  }

  @override
  Future<bool> hasUnsettledObligations(String accountId) async {
    if (await _bills.hasUnsettledItems(accountId)) {
      return true;
    }
    final schedules = await _installments.listSchedulesByLiabilityAccount(
      accountId,
    );
    return schedules.any(
      (schedule) =>
          schedule.status == InstallmentScheduleStatus.pending ||
          schedule.status == InstallmentScheduleStatus.partiallyPaid,
    );
  }

  Future<Map<String, InstallmentContract>> _contractsById(
    String accountId,
  ) async {
    final contracts = await _installments.listContractsByLiabilityAccount(
      accountId,
    );
    return {for (final contract in contracts) contract.id: contract};
  }

  BillSummaryReadModel _summaryForBill({
    required Bill bill,
    required DateTime now,
    required Map<String, RepaymentAmountBreakdown> allocatedByItemId,
  }) {
    final dueDate = bill.window?.repaymentDate ?? _earliestRepaymentDate(bill);
    final overdueCount =
        bill.items.where((item) {
          return _isOutstanding(item.status) &&
              _dateOnly(item.repaymentDate).isBefore(_dateOnly(now));
        }).length;
    return BillSummaryReadModel(
      id: bill.id,
      accountId: bill.accountId,
      period: bill.period,
      status: bill.status,
      dueDate: dueDate,
      expectedPrincipal: bill.expectedPrincipal,
      expectedInterest: bill.expectedInterest,
      expectedFee: bill.expectedFee,
      pendingPrincipal: _pendingPrincipalForBill(bill, allocatedByItemId),
      itemCount: bill.items.length,
      overdueItemCount: overdueCount,
    );
  }

  BillItemReadModel _itemForBill({
    required BillItem item,
    required DateTime now,
    required CreditLiabilityAccountKind? accountKind,
    required InstallmentContract? contract,
    required RepaymentAmountBreakdown allocated,
  }) {
    return BillItemReadModel(
      id: item.id,
      itemType: item.itemType,
      label: _itemLabel(
        item: item,
        accountKind: accountKind,
        contract: contract,
      ),
      status: item.status,
      repaymentDate: item.repaymentDate,
      expectedPrincipal: item.expectedPrincipal,
      expectedInterest: item.expectedInterest,
      expectedFee: item.expectedFee,
      allocated: allocated,
      contractId: item.contractId,
      scheduleId: item.scheduleId,
      isOverdue:
          _isOutstanding(item.status) &&
          _dateOnly(item.repaymentDate).isBefore(_dateOnly(now)),
    );
  }

  Money _pendingPrincipalForBill(
    Bill bill,
    Map<String, RepaymentAmountBreakdown> allocatedByItemId,
  ) {
    var total = 0;
    for (final item in bill.items) {
      if (!_isOutstanding(item.status)) continue;
      final allocatedPrincipal =
          allocatedByItemId[item.id]?.principal.minorUnits ?? 0;
      final remaining = item.expectedPrincipal.minorUnits - allocatedPrincipal;
      if (remaining > 0) total += remaining;
    }
    return Money(minorUnits: total);
  }

  bool _isOutstanding(BillItemStatus status) {
    return status == BillItemStatus.pending ||
        status == BillItemStatus.partiallyPaid;
  }

  String _itemLabel({
    required BillItem item,
    required CreditLiabilityAccountKind? accountKind,
    required InstallmentContract? contract,
  }) {
    if (item.itemType == BillItemType.consumption) {
      return '消费';
    }
    if (contract == null) {
      return '分期';
    }
    return switch (contract.sourceType) {
      InstallmentSourceType.billConversion => '账单分期',
      InstallmentSourceType.disbursement =>
        accountKind == CreditLiabilityAccountKind.credit ? '现金分期' : '贷款分期',
    };
  }

  Future<List<BillRepaymentReadModel>> _repaymentsForBill(Bill bill) async {
    final repayments = await _repayments.listByTarget(
      RepaymentTargetType.bill,
      bill.id,
    );
    return [
      for (final repayment in repayments)
        await _repaymentForBill(repayment, fallbackTime: _currentTime()),
    ];
  }

  Future<BillRepaymentReadModel> _repaymentForBill(
    Repayment repayment, {
    required DateTime fallbackTime,
  }) async {
    final total = repayment.totalAllocated();
    final rootTransactionId = repayment.rootTransactionId;
    final detail =
        rootTransactionId == null
            ? null
            : await _ledger.findCurrentParentTransactionByRoot(
              rootTransactionId,
            );
    final usesTransaction = detail != null;
    return BillRepaymentReadModel(
      id: repayment.id,
      repaymentType: repayment.repaymentType,
      allocated: total,
      displayTime:
          usesTransaction
              ? detail.occurredAt
              : repayment.createdAt ?? fallbackTime,
      timeSource:
          usesTransaction
              ? BillRepaymentTimeSource.transaction
              : BillRepaymentTimeSource.recordCreatedAt,
      rootTransactionId: rootTransactionId,
      paidFromAccountId: usesTransaction ? detail.paidFromAccountId : null,
    );
  }

  DateTime? _earliestRepaymentDate(Bill bill) {
    if (bill.items.isEmpty) return null;
    final dates = bill.items.map((item) => item.repaymentDate).toList()..sort();
    return dates.first;
  }

  DateTime _currentTime() {
    final now = _now;
    return now == null ? DateTime.now() : now();
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
