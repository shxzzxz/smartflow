import 'dart:math' as math;

import 'package:smartflow/application/ledger/ledger_query_api.dart'
    as ledger_query;
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/entity/credit_liability_account.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/credit_account_repository.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/service/debt/credit_debt_bucket_service.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/bill_period.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_amount_breakdown.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

import 'credit_account_queries.dart';
import 'credit_account_read_models.dart';

abstract interface class CreditAccountQueryService {
  Stream<Map<String, CreditLiabilityAccount>>
  watchCreditLiabilityAccountsByAccountId();

  Future<CreditLiabilityAccount?> findByAccountId(String accountId);

  Future<CreditAccountOverviewReadModel?> findOverview(String accountId);

  Future<ContractEffectiveRateReadModel?> calculateContractEffectiveRates(
    String contractId,
  );

  Future<List<CreditDueCalendarItemReadModel>> listDueCalendarItems(
    CreditDueCalendarQuery query,
  );

  Future<List<MonthlyBillSummaryReadModel>> listMonthlyBillSummaries(
    MonthlyBillSummaryQuery query,
  );
}

class CreditAccountQueryServiceImpl implements CreditAccountQueryService {
  const CreditAccountQueryServiceImpl({
    required CreditAccountRepository creditAccounts,
    required BillRepository bills,
    required InstallmentRepository installments,
    required RepaymentRepository repayments,
    required ledger_query.AccountQueryService accountQueryService,
    required ledger_query.TransactionQueryService transactionQueryService,
    CreditDebtBucketService debtBuckets = const CreditDebtBucketService(),
  }) : _creditAccounts = creditAccounts,
       _bills = bills,
       _installments = installments,
       _repayments = repayments,
       _accountQueryService = accountQueryService,
       _transactionQueryService = transactionQueryService,
       _debtBuckets = debtBuckets;

  final CreditAccountRepository _creditAccounts;
  final BillRepository _bills;
  final InstallmentRepository _installments;
  final RepaymentRepository _repayments;
  final ledger_query.AccountQueryService _accountQueryService;
  final ledger_query.TransactionQueryService _transactionQueryService;
  final CreditDebtBucketService _debtBuckets;

  @override
  Stream<Map<String, CreditLiabilityAccount>>
  watchCreditLiabilityAccountsByAccountId() {
    return _creditAccounts.watchByAccountId();
  }

  @override
  Future<CreditLiabilityAccount?> findByAccountId(String accountId) {
    return _creditAccounts.findByAccountId(accountId);
  }

  @override
  Future<CreditAccountOverviewReadModel?> findOverview(String accountId) async {
    final creditAccount = await _creditAccounts.findByAccountId(accountId);
    if (creditAccount == null) return null;
    final account = await _accountQueryService.findAccountById(accountId);
    if (account == null) return null;

    final buckets = await _debtBuckets.bucketsForAccount(
      accountId: accountId,
      liabilityBalance: account.balance,
      bills: _bills,
      installments: _installments,
      repayments: _repayments,
    );
    final repayments = await _repayments.listByTarget(
      RepaymentTargetType.account,
      accountId,
    );
    return CreditAccountOverviewReadModel(
      creditAccount: creditAccount,
      liabilityBalance: account.balance,
      availableCredit:
          creditAccount.creditLimit == null
              ? null
              : creditAccount.creditLimit! - account.balance,
      buckets: buckets,
      unattributedRepayments: [
        for (final repayment in repayments)
          await _repaymentRecord(repayment, fallbackTime: DateTime.now()),
      ],
    );
  }

  @override
  Future<ContractEffectiveRateReadModel?> calculateContractEffectiveRates(
    String contractId,
  ) async {
    final contract = await _installments.findContract(contractId);
    if (contract == null) return null;
    final schedules = await _installments.listSchedules(contractId);
    final actualCashflows = await _actualContractCashflows(contract, schedules);
    final pendingSchedules =
        schedules
            .where(
              (schedule) =>
                  schedule.status == InstallmentScheduleStatus.pending,
            )
            .toList()
          ..sort(
            (a, b) =>
                a.expectedRepaymentDate.compareTo(b.expectedRepaymentDate),
          );

    final actualPrincipal = actualCashflows.fold<int>(
      0,
      (sum, cashflow) => sum + cashflow.principal.minorUnits,
    );
    final pendingPrincipal = pendingSchedules.fold<int>(
      0,
      (sum, schedule) => sum + schedule.expectedPrincipal.minorUnits,
    );
    if (actualPrincipal + pendingPrincipal != contract.principal.minorUnits) {
      return ContractEffectiveRateReadModel.unavailable(
        contractId: contract.id,
        reason: ContractEffectiveRateUnavailableReason.principalMismatch,
      );
    }

    final datedCashflows = <_DatedCashflow>[
      _DatedCashflow(
        date: contract.borrowingDate,
        amount: contract.principal.minorUnits.toDouble(),
      ),
      for (final cashflow in actualCashflows)
        _DatedCashflow(
          date: cashflow.occurredAt,
          amount:
              -_cashOutMinor(
                principal: cashflow.principal,
                interest: cashflow.interest,
                fee: cashflow.fee,
              ).toDouble(),
        ),
      for (final schedule in pendingSchedules)
        _DatedCashflow(
          date: schedule.expectedRepaymentDate,
          amount:
              -_cashOutMinor(
                principal: schedule.expectedPrincipal,
                interest: schedule.expectedInterest,
                fee: schedule.expectedFee,
              ).toDouble(),
        ),
    ]..sort((a, b) => a.date.compareTo(b.date));
    final xirr = _xirr(datedCashflows);
    if (!xirr.converged) {
      return ContractEffectiveRateReadModel.unavailable(
        contractId: contract.id,
        reason: ContractEffectiveRateUnavailableReason.notConverged,
      );
    }
    final monthlyIrr = math.pow(1 + xirr.rate, 1 / 12) - 1;
    return ContractEffectiveRateReadModel.available(
      contractId: contract.id,
      monthlyIrr: monthlyIrr.toDouble(),
      nominalApr: (monthlyIrr * 12).toDouble(),
      effectiveApr: xirr.rate,
      totalRepayment: Money(
        minorUnits: [
          for (final cashflow in actualCashflows)
            _cashOutMinor(
              principal: cashflow.principal,
              interest: cashflow.interest,
              fee: cashflow.fee,
            ),
          for (final schedule in pendingSchedules)
            _cashOutMinor(
              principal: schedule.expectedPrincipal,
              interest: schedule.expectedInterest,
              fee: schedule.expectedFee,
            ),
        ].fold(0, (sum, amount) => sum + amount),
      ),
    );
  }

  @override
  Future<List<CreditDueCalendarItemReadModel>> listDueCalendarItems(
    CreditDueCalendarQuery query,
  ) async {
    final accounts = await _matchingCreditAccounts(query.accountId);
    final result = <CreditDueCalendarItemReadModel>[];
    for (final account in accounts) {
      final bills = await _bills.listBillsByAccount(account.accountId);
      final billedScheduleIds = <String>{};
      for (final bill in bills) {
        for (final item in bill.items) {
          if ((item.status != BillItemStatus.pending &&
                  item.status != BillItemStatus.partiallyPaid) ||
              !_inWindow(item.repaymentDate, query.from, query.until)) {
            continue;
          }
          if (item.scheduleId != null) billedScheduleIds.add(item.scheduleId!);
          result.add(
            CreditDueCalendarItemReadModel.billItem(
              accountId: account.accountId,
              billId: bill.id,
              billItemId: item.id,
              dueDate: item.repaymentDate,
              itemType: item.itemType,
              principal: item.expectedPrincipal,
              interest: item.expectedInterest,
              fee: item.expectedFee,
              contractId: item.contractId,
              scheduleId: item.scheduleId,
            ),
          );
        }
      }

      final schedules = await _installments.listSchedulesByLiabilityAccount(
        account.accountId,
      );
      for (final schedule in schedules) {
        if ((schedule.status != InstallmentScheduleStatus.pending &&
                schedule.status != InstallmentScheduleStatus.partiallyPaid) ||
            billedScheduleIds.contains(schedule.id) ||
            !_inWindow(
              schedule.expectedRepaymentDate,
              query.from,
              query.until,
            )) {
          continue;
        }
        result.add(
          CreditDueCalendarItemReadModel.schedule(
            accountId: account.accountId,
            contractId: schedule.contractId,
            scheduleId: schedule.id,
            dueDate: schedule.expectedRepaymentDate,
            principal: schedule.expectedPrincipal,
            interest: schedule.expectedInterest,
            fee: schedule.expectedFee,
          ),
        );
      }
    }
    result.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return result;
  }

  @override
  Future<List<MonthlyBillSummaryReadModel>> listMonthlyBillSummaries(
    MonthlyBillSummaryQuery query,
  ) async {
    final accounts = await _matchingCreditAccounts(query.accountId);
    final period = BillPeriod(year: query.month.year, month: query.month.month);
    final accountBills = <({CreditLiabilityAccount account, Bill bill})>[];
    for (final account in accounts) {
      final bill = await _bills.findByAccountAndPeriod(
        account.accountId,
        period,
      );
      if (bill == null) continue;
      accountBills.add((account: account, bill: bill));
    }
    final allocatedByItemId = await _repayments.aggregateItemsByBillItemIds(
      accountBills.expand((entry) => entry.bill.items).map((item) => item.id),
    );
    final result = <MonthlyBillSummaryReadModel>[];
    for (final (:account, :bill) in accountBills) {
      var pendingPrincipalMinor = 0;
      for (final item in bill.items) {
        pendingPrincipalMinor += _debtBuckets.remainingPrincipalForBillItem(
          item,
          allocatedPrincipalMinor:
              allocatedByItemId[item.id]?.principal.minorUnits ?? 0,
        );
      }
      result.add(
        MonthlyBillSummaryReadModel(
          accountId: account.accountId,
          billId: bill.id,
          period: bill.period,
          dueDate: bill.window?.repaymentDate ?? _earliestRepaymentDate(bill),
          status: bill.status,
          expectedPrincipal: bill.expectedPrincipal,
          expectedInterest: bill.expectedInterest,
          expectedFee: bill.expectedFee,
          pendingPrincipal: Money(minorUnits: pendingPrincipalMinor),
          itemCount: bill.items.length,
        ),
      );
    }
    result.sort((a, b) => a.accountId.compareTo(b.accountId));
    return result;
  }

  Future<List<_ActualContractCashflow>> _actualContractCashflows(
    InstallmentContract contract,
    List<InstallmentSchedule> schedules,
  ) async {
    final schedulesById = {
      for (final schedule in schedules) schedule.id: schedule,
    };
    final cashflows = <_ActualContractCashflow>[];

    final directRepayments = await _repayments.listByTarget(
      RepaymentTargetType.contract,
      contract.id,
    );
    for (final repayment in directRepayments) {
      final cashflow = await _cashflowForRepayment(
        repayment,
        repayment.totalAllocated(),
        scheduleId: null,
      );
      if (cashflow != null) cashflows.add(cashflow);
    }

    final bills = await _bills.listBillsByAccount(contract.liabilityAccountId);
    final seenRepaymentItems = <String>{};
    for (final bill in bills) {
      for (final item in bill.items) {
        if (item.contractId != contract.id || item.scheduleId == null) {
          continue;
        }
        final schedule = schedulesById[item.scheduleId!];
        if (schedule == null) continue;
        final repaymentItems = await _repayments.listItemsByBillItem(item.id);
        for (final repaymentItem in repaymentItems) {
          if (!seenRepaymentItems.add(repaymentItem.id)) continue;
          final repayment = await _repayments.findRepayment(
            repaymentItem.repaymentId,
          );
          if (repayment == null) continue;
          final cashflow = await _cashflowForRepayment(
            repayment,
            repaymentItem.allocated,
            scheduleId: schedule.id,
          );
          if (cashflow != null) cashflows.add(cashflow);
        }
      }
    }

    cashflows.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return cashflows;
  }

  Future<_ActualContractCashflow?> _cashflowForRepayment(
    Repayment repayment,
    RepaymentAmountBreakdown allocated, {
    required String? scheduleId,
  }) async {
    final rootTransactionId = repayment.rootTransactionId;
    if (rootTransactionId == null) return null;
    final detail = await _transactionQueryService
        .findCurrentParentTransactionDetailByRoot(rootTransactionId);
    final transaction = detail?.transaction;
    if (transaction == null ||
        transaction.businessState != BusinessState.current) {
      return null;
    }
    return _ActualContractCashflow(
      repaymentId: repayment.id,
      scheduleId: scheduleId,
      occurredAt: transaction.occurredAt,
      principal: allocated.principal,
      interest: allocated.interest,
      fee: allocated.fee,
    );
  }

  Future<CreditRepaymentRecordReadModel> _repaymentRecord(
    Repayment repayment, {
    required DateTime fallbackTime,
  }) async {
    final rootTransactionId = repayment.rootTransactionId;
    final detail =
        rootTransactionId == null
            ? null
            : await _transactionQueryService
                .findCurrentParentTransactionDetailByRoot(rootTransactionId);
    final transaction = detail?.transaction;
    final usesTransaction =
        transaction != null &&
        transaction.businessState == BusinessState.current;
    return CreditRepaymentRecordReadModel(
      id: repayment.id,
      repaymentType: repayment.repaymentType,
      allocated: repayment.totalAllocated(),
      displayTime:
          usesTransaction
              ? transaction.occurredAt
              : repayment.createdAt ?? fallbackTime,
      timeSource:
          usesTransaction
              ? CreditRepaymentTimeSource.transaction
              : CreditRepaymentTimeSource.recordCreatedAt,
      rootTransactionId: rootTransactionId,
      paidFromAccountId:
          usesTransaction && detail != null ? _paidFromAccountId(detail) : null,
    );
  }

  Future<List<CreditLiabilityAccount>> _matchingCreditAccounts(
    String? accountId,
  ) async {
    if (accountId != null) {
      final account = await _creditAccounts.findByAccountId(accountId);
      return account == null ? const [] : [account];
    }
    return _creditAccounts.listAll();
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

  bool _inWindow(DateTime value, DateTime from, DateTime until) {
    return !value.isBefore(from) && value.isBefore(until);
  }

  int _cashOutMinor({
    required Money principal,
    required Money interest,
    required Money fee,
  }) {
    return principal.minorUnits + interest.minorUnits + fee.minorUnits;
  }

  _XirrResult _xirr(List<_DatedCashflow> flows) {
    if (flows.length < 2) return const _XirrResult(rate: 0, converged: false);
    final hasPositive = flows.any((flow) => flow.amount > 0);
    final hasNegative = flows.any((flow) => flow.amount < 0);
    if (!hasPositive || !hasNegative) {
      return const _XirrResult(rate: 0, converged: false);
    }

    final t0 = flows.first.date;
    final ts =
        flows.map((flow) => flow.date.difference(t0).inDays / 365.0).toList();
    final cfs = flows.map((flow) => flow.amount).toList();

    double f(double rate) {
      var sum = 0.0;
      for (var i = 0; i < cfs.length; i++) {
        sum += cfs[i] / math.pow(1 + rate, ts[i]);
      }
      return sum;
    }

    double df(double rate) {
      var sum = 0.0;
      for (var i = 0; i < cfs.length; i++) {
        sum += -ts[i] * cfs[i] / math.pow(1 + rate, ts[i] + 1);
      }
      return sum;
    }

    var rate = 0.1;
    for (var i = 0; i < 100; i++) {
      final value = f(rate);
      final derivative = df(rate);
      if (derivative.abs() < 1e-12) break;
      final next = rate - value / derivative;
      if (!next.isFinite || next <= -0.999) break;
      if ((next - rate).abs() < 1e-9) {
        return _XirrResult(rate: next, converged: true);
      }
      rate = next;
    }

    var lo = -0.99;
    var hi = 10.0;
    var fLo = f(lo);
    var fHi = f(hi);
    if (fLo.sign == fHi.sign) {
      return _XirrResult(rate: rate, converged: false);
    }
    for (var i = 0; i < 200; i++) {
      final mid = (lo + hi) / 2;
      final fMid = f(mid);
      if (fMid.abs() < 1e-9 || (hi - lo) < 1e-10) {
        return _XirrResult(rate: mid, converged: true);
      }
      if (fMid.sign == fLo.sign) {
        lo = mid;
        fLo = fMid;
      } else {
        hi = mid;
        fHi = fMid;
      }
    }
    return _XirrResult(rate: (lo + hi) / 2, converged: false);
  }
}

class _ActualContractCashflow {
  const _ActualContractCashflow({
    required this.repaymentId,
    required this.occurredAt,
    required this.principal,
    required this.interest,
    required this.fee,
    this.scheduleId,
  });

  final String repaymentId;
  final String? scheduleId;
  final DateTime occurredAt;
  final Money principal;
  final Money interest;
  final Money fee;
}

class _DatedCashflow {
  const _DatedCashflow({required this.date, required this.amount});

  final DateTime date;
  final double amount;
}

class _XirrResult {
  const _XirrResult({required this.rate, required this.converged});

  final double rate;
  final bool converged;
}
