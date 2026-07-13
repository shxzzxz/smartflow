import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/entity/credit_liability_account.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/credit_account_repository.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/service/debt/credit_debt_bucket_service.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/bill_period.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

import 'credit_account_queries.dart';
import 'credit_account_read_models.dart';

abstract interface class CreditAccountQueryService {
  Stream<Map<String, CreditLiabilityAccount>>
  watchCreditLiabilityAccountsByAccountId();

  Future<CreditLiabilityAccount?> findByAccountId(String accountId);

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
  }) : _creditAccounts = creditAccounts,
       _bills = bills,
       _installments = installments,
       _repayments = repayments,
       _ledger = ledger,
       _debtBuckets = debtBuckets;

  final CreditAccountRepository _creditAccounts;
  final BillRepository _bills;
  final InstallmentRepository _installments;
  final RepaymentRepository _repayments;
  final CreditLedgerPort _ledger;
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
    final account = await _ledger.findAccount(accountId);
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

  Future<CreditRepaymentRecordReadModel> _repaymentRecord(
    Repayment repayment, {
    required DateTime fallbackTime,
  }) async {
    final rootTransactionId = repayment.rootTransactionId;
    final detail =
        rootTransactionId == null
            ? null
            : await _ledger.findCurrentParentTransactionByRoot(
              rootTransactionId,
            );
    final usesTransaction = detail != null;
    return CreditRepaymentRecordReadModel(
      id: repayment.id,
      repaymentType: repayment.repaymentType,
      allocated: repayment.totalAllocated(),
      displayTime:
          usesTransaction
              ? detail.occurredAt
              : repayment.createdAt ?? fallbackTime,
      timeSource:
          usesTransaction
              ? CreditRepaymentTimeSource.transaction
              : CreditRepaymentTimeSource.recordCreatedAt,
      rootTransactionId: rootTransactionId,
      paidFromAccountId: usesTransaction ? detail.paidFromAccountId : null,
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

  DateTime? _earliestRepaymentDate(Bill bill) {
    if (bill.items.isEmpty) return null;
    final dates = bill.items.map((item) => item.repaymentDate).toList()..sort();
    return dates.first;
  }

  bool _inWindow(DateTime value, DateTime from, DateTime until) {
    return !value.isBefore(from) && value.isBefore(until);
  }
}
