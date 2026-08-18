import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/entity/credit_liability_account.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/credit_account_repository.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/service/debt/credit_debt_bucket_service.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/bill_period.dart';
import 'package:smartflow/domain/credit/valobj/repayment_amount_breakdown.dart';

import 'credit_account_queries.dart';
import 'credit_account_read_models.dart';

abstract interface class CreditAccountQueryService {
  Stream<Map<String, CreditLiabilityAccountReadModel>>
  watchCreditLiabilityAccountsByAccountId();

  Future<CreditLiabilityAccountReadModel?> findByAccountId(String accountId);

  Future<CreditAccountOverviewReadModel?> findOverview(String accountId);

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
    required CreditLedgerPort ledger,
    CreditDebtBucketService debtBuckets = const CreditDebtBucketService(),
    DateTime Function()? now,
  }) : _creditAccounts = creditAccounts,
       _bills = bills,
       _installments = installments,
       _repayments = repayments,
       _ledger = ledger,
       _debtBuckets = debtBuckets,
       _now = now;

  final CreditAccountRepository _creditAccounts;
  final BillRepository _bills;
  final InstallmentRepository _installments;
  final RepaymentRepository _repayments;
  final CreditLedgerPort _ledger;
  final CreditDebtBucketService _debtBuckets;
  final DateTime Function()? _now;

  @override
  Stream<Map<String, CreditLiabilityAccountReadModel>>
  watchCreditLiabilityAccountsByAccountId() {
    return _creditAccounts.watchByAccountId().map(
      (accounts) =>
          accounts.map((key, value) => MapEntry(key, _accountReadModel(value))),
    );
  }

  @override
  Future<CreditLiabilityAccountReadModel?> findByAccountId(
    String accountId,
  ) async {
    final account = await _creditAccounts.findByAccountId(accountId);
    return account == null ? null : _accountReadModel(account);
  }

  @override
  Future<CreditAccountOverviewReadModel?> findOverview(String accountId) async {
    final creditAccount = await _creditAccounts.findByAccountId(accountId);
    if (creditAccount == null) return null;
    final account = await _ledger.findAccount(accountId);
    if (account == null) return null;

    final domainBuckets = await _debtBuckets.bucketsForAccount(
      accountId: accountId,
      liabilityBalance: account.balance,
      bills: _bills,
      installments: _installments,
      repayments: _repayments,
    );
    return CreditAccountOverviewReadModel(
      creditAccount: _accountReadModel(creditAccount),
      liabilityBalance: account.balance,
      availableCredit:
          creditAccount.creditLimit == null
              ? null
              : creditAccount.creditLimit! - account.balance,
      buckets: CreditDebtBucketsReadModel(
        billDebt: domainBuckets.billDebt,
        futureContractDebt: domainBuckets.futureContractDebt,
        unattributedDebt: domainBuckets.unattributedDebt,
      ),
    );
  }

  CreditLiabilityAccountReadModel _accountReadModel(
    CreditLiabilityAccount account,
  ) {
    return CreditLiabilityAccountReadModel(
      id: account.id,
      accountId: account.accountId,
      kind: account.kind,
      creditLimit: account.creditLimit,
      billingDay: account.billingDay,
      repaymentDay: account.repaymentDay,
      billingDayToNext: account.billingDayToNext,
    );
  }

  @override
  Future<List<CreditDueCalendarItemReadModel>> listDueCalendarItems(
    CreditDueCalendarQuery query,
  ) async {
    final accounts = await _matchingCreditAccounts(query.accountId);
    final today = _dateOnly(_currentTime());
    final result = <CreditDueCalendarItemReadModel>[];
    for (final account in accounts) {
      final bills = await _bills.listBillsByAccount(account.accountId);
      final dueItems = [
        for (final bill in bills)
          for (final item in bill.items)
            if ((item.status == BillItemStatus.pending ||
                    item.status == BillItemStatus.partiallyPaid) &&
                _inWindow(item.repaymentDate, query.from, query.until))
              (bill: bill, item: item),
      ];
      final allocatedByItemId = await _repayments.aggregateItemsByBillItemIds(
        dueItems.map((entry) => entry.item.id),
      );
      for (final (:bill, :item) in dueItems) {
        final allocated =
            allocatedByItemId[item.id] ?? RepaymentAmountBreakdown.zero;
        final remainingPrincipal = _remaining(
          item.expectedPrincipal.minorUnits,
          allocated.principal.minorUnits,
        );
        final remainingInterest = _remaining(
          item.expectedInterest.minorUnits,
          allocated.interest.minorUnits,
        );
        final remainingFee = _remaining(
          item.expectedFee.minorUnits,
          allocated.fee.minorUnits,
        );
        final pendingTotal = _debtBuckets.remainingTotalForBillItem(
          item,
          allocated: allocated,
        );
        result.add(
          CreditDueCalendarItemReadModel.billItem(
            accountId: account.accountId,
            billId: bill.id,
            billItemId: item.id,
            dueDate: item.repaymentDate,
            itemType: item.itemType,
            status: item.status,
            principal: Money(minorUnits: remainingPrincipal),
            interest: Money(minorUnits: remainingInterest),
            fee: Money(minorUnits: remainingFee),
            discount: allocated.discount,
            pendingTotal: Money(minorUnits: pendingTotal),
            isOverdue: _dateOnly(item.repaymentDate).isBefore(today),
            contractId: item.contractId,
            scheduleId: item.scheduleId,
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
      var pendingTotalMinor = 0;
      for (final item in bill.items) {
        final allocated =
            allocatedByItemId[item.id] ?? RepaymentAmountBreakdown.zero;
        pendingPrincipalMinor += _debtBuckets.remainingPrincipalForBillItem(
          item,
          allocatedPrincipalMinor: allocated.principal.minorUnits,
        );
        pendingTotalMinor += _debtBuckets.remainingTotalForBillItem(
          item,
          allocated: allocated,
        );
      }
      result.add(
        MonthlyBillSummaryReadModel(
          accountId: account.accountId,
          billId: bill.id,
          period: bill.period,
          status: bill.status,
          expectedPrincipal: bill.expectedPrincipal,
          expectedInterest: bill.expectedInterest,
          expectedFee: bill.expectedFee,
          pendingPrincipal: Money(minorUnits: pendingPrincipalMinor),
          pendingTotal: Money(minorUnits: pendingTotalMinor),
          itemCount: bill.items.length,
        ),
      );
    }
    result.sort((a, b) => a.accountId.compareTo(b.accountId));
    return result;
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

  bool _inWindow(DateTime value, DateTime from, DateTime until) {
    return !value.isBefore(from) && value.isBefore(until);
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _currentTime() {
    final now = _now;
    return now == null ? DateTime.now() : now();
  }

  int _remaining(int expected, int allocated) {
    final value = expected - allocated;
    return value < 0 ? 0 : value;
  }
}
