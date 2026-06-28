import 'package:smartflow/application/ledger/ledger_query_api.dart'
    as ledger_query;
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/credit_account_repository.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/bill_period.dart';
import 'package:smartflow/domain/credit/valobj/credit_account_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_amount_breakdown.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

import '../command/credit_bill_generation_service.dart';

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
    required ledger_query.TransactionQueryService transactionQueryService,
    required CreditBillGenerationService generationService,
    DateTime Function()? now,
  }) : _bills = bills,
       _creditAccounts = creditAccounts,
       _installments = installments,
       _repayments = repayments,
       _transactionQueryService = transactionQueryService,
       _generationService = generationService,
       _now = now;

  final BillRepository _bills;
  final CreditAccountRepository _creditAccounts;
  final InstallmentRepository _installments;
  final RepaymentRepository _repayments;
  final ledger_query.TransactionQueryService _transactionQueryService;
  final CreditBillGenerationService _generationService;
  final DateTime Function()? _now;

  @override
  Future<List<BillSummaryReadModel>> listBillsByAccount(
    String accountId,
  ) async {
    final now = _currentTime();
    await _generationService.generateDueBillsForAccount(
      accountId: accountId,
      now: now,
    );
    final bills = await _bills.listBillsByAccount(accountId);
    return [
      for (final bill in bills)
        _summaryForBill(bill: bill, now: now, hasSourceDiff: false),
    ];
  }

  @override
  Future<BillDetailReadModel?> findBillDetail(String billId) async {
    final initial = await _bills.findBill(billId);
    if (initial == null) return null;
    final now = _currentTime();
    await _generationService.generateDueBillsForAccount(
      accountId: initial.accountId,
      now: now,
    );
    final bill = await _bills.findBill(billId);
    if (bill == null) return null;
    final creditAccount = await _creditAccounts.findByAccountId(bill.accountId);
    final contracts = await _contractsById(bill.accountId);
    final repayments = await _repaymentsForBill(bill);
    return BillDetailReadModel(
      summary: _summaryForBill(bill: bill, now: now, hasSourceDiff: false),
      items: [
        for (final item in bill.items)
          _itemForBill(
            item: item,
            now: now,
            accountKind: creditAccount?.kind,
            contract: contracts[item.contractId],
          ),
      ],
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
      (schedule) => schedule.status == InstallmentScheduleStatus.pending,
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
    required bool hasSourceDiff,
  }) {
    final dueDate = bill.window?.repaymentDate ?? _earliestRepaymentDate(bill);
    final overdueCount =
        bill.items.where((item) {
          return item.status == BillItemStatus.pending &&
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
      pendingPrincipal: bill.pendingPrincipal,
      itemCount: bill.items.length,
      overdueItemCount: overdueCount,
      hasSourceDiff: hasSourceDiff,
    );
  }

  BillItemReadModel _itemForBill({
    required BillItem item,
    required DateTime now,
    required CreditLiabilityAccountKind? accountKind,
    required InstallmentContract? contract,
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
      contractId: item.contractId,
      scheduleId: item.scheduleId,
      isOverdue:
          item.status == BillItemStatus.pending &&
          _dateOnly(item.repaymentDate).isBefore(_dateOnly(now)),
    );
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
            : await _transactionQueryService.findTransactionDetail(
              rootTransactionId,
            );
    final transaction = detail?.transaction;
    final usesTransaction =
        transaction != null &&
        transaction.businessState == BusinessState.current;
    return BillRepaymentReadModel(
      id: repayment.id,
      repaymentType: repayment.repaymentType,
      allocated: total,
      displayTime:
          usesTransaction
              ? transaction.occurredAt
              : repayment.createdAt ?? fallbackTime,
      timeSource:
          usesTransaction
              ? BillRepaymentTimeSource.transaction
              : BillRepaymentTimeSource.recordCreatedAt,
      rootTransactionId: rootTransactionId,
      paidFromAccountId:
          usesTransaction && detail != null ? _paidFromAccountId(detail) : null,
    );
  }

  String? _paidFromAccountId(ledger_query.TransactionDetail detail) {
    final paidAmount = detail.transaction.primaryAmount;
    for (final entry in detail.entries.reversed) {
      if (entry.direction == EntryDirection.credit &&
          entry.amount == paidAmount) {
        return entry.accountId;
      }
    }
    return null;
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

class BillSummaryReadModel {
  const BillSummaryReadModel({
    required this.id,
    required this.accountId,
    required this.period,
    required this.status,
    required this.expectedPrincipal,
    required this.expectedInterest,
    required this.expectedFee,
    required this.pendingPrincipal,
    required this.itemCount,
    required this.overdueItemCount,
    required this.hasSourceDiff,
    this.dueDate,
  });

  final String id;
  final String accountId;
  final BillPeriod period;
  final BillStatus status;
  final DateTime? dueDate;
  final Money expectedPrincipal;
  final Money expectedInterest;
  final Money expectedFee;
  final Money pendingPrincipal;
  final int itemCount;
  final int overdueItemCount;
  final bool hasSourceDiff;
}

class BillDetailReadModel {
  const BillDetailReadModel({
    required this.summary,
    required this.items,
    required this.repayments,
  });

  final BillSummaryReadModel summary;
  final List<BillItemReadModel> items;
  final List<BillRepaymentReadModel> repayments;
}

class BillItemReadModel {
  const BillItemReadModel({
    required this.id,
    required this.itemType,
    required this.label,
    required this.status,
    required this.repaymentDate,
    required this.expectedPrincipal,
    required this.expectedInterest,
    required this.expectedFee,
    required this.isOverdue,
    this.contractId,
    this.scheduleId,
  });

  final String id;
  final BillItemType itemType;
  final String label;
  final BillItemStatus status;
  final DateTime repaymentDate;
  final Money expectedPrincipal;
  final Money expectedInterest;
  final Money expectedFee;
  final bool isOverdue;
  final String? contractId;
  final String? scheduleId;
}

enum BillRepaymentTimeSource { transaction, recordCreatedAt }

class BillRepaymentReadModel {
  const BillRepaymentReadModel({
    required this.id,
    required this.repaymentType,
    required this.allocated,
    required this.displayTime,
    required this.timeSource,
    this.rootTransactionId,
    this.paidFromAccountId,
  });

  final String id;
  final RepaymentType repaymentType;
  final RepaymentAmountBreakdown allocated;
  final DateTime displayTime;
  final BillRepaymentTimeSource timeSource;
  final String? rootTransactionId;
  final String? paidFromAccountId;

  Money get cashPaid =>
      allocated.principal +
      allocated.interest +
      allocated.fee -
      allocated.discount;
}
