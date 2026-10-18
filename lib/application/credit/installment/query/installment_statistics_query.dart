import '../../../../core/money/money.dart';
import '../../../../domain/credit/entity/installment_contract.dart';
import '../../../../domain/credit/entity/installment_schedule.dart';
import '../../../../domain/credit/port/bill_repository.dart';
import '../../../../domain/credit/port/installment_repository.dart';
import '../../../../domain/credit/port/repayment_repository.dart';
import '../../../../domain/credit/service/debt/credit_debt_bucket_service.dart';
import '../../../../domain/credit/service/installment/calculator/installment_metrics.dart'
    as domain;
import '../../../../domain/credit/service/installment/installment_plan_engine.dart';
import '../../../../domain/credit/valobj/bill_enums.dart';
import '../../../../domain/credit/valobj/installment_enums.dart';
import '../../../../domain/credit/valobj/repayment_amount_breakdown.dart';
import 'installment_statistics_read_models.dart';
import 'port/installment_statistics_change_source.dart';

abstract interface class InstallmentStatisticsQuery {
  /// 当前状态下进行中合同的待还构成与未来还款走势。
  Stream<InstallmentStatisticsReadModel> watchStatistics({
    required DateTime asOf,
    required Set<String> liabilityAccountIds,
  });
}

class InstallmentStatisticsQueryImpl implements InstallmentStatisticsQuery {
  const InstallmentStatisticsQueryImpl({
    required InstallmentRepository installments,
    required BillRepository bills,
    required RepaymentRepository repayments,
    required InstallmentStatisticsChangeSource changes,
    CreditDebtBucketService debtBuckets = const CreditDebtBucketService(),
    domain.InstallmentMetricsCalculator calculator =
        const domain.InstallmentMetricsCalculator(),
  }) : _installments = installments,
       _bills = bills,
       _repayments = repayments,
       _changes = changes,
       _debtBuckets = debtBuckets,
       _calculator = calculator;

  final InstallmentRepository _installments;
  final BillRepository _bills;
  final RepaymentRepository _repayments;
  final InstallmentStatisticsChangeSource _changes;
  final CreditDebtBucketService _debtBuckets;
  final domain.InstallmentMetricsCalculator _calculator;

  @override
  Stream<InstallmentStatisticsReadModel> watchStatistics({
    required DateTime asOf,
    required Set<String> liabilityAccountIds,
  }) {
    final accountIds = Set<String>.unmodifiable(liabilityAccountIds);
    final normalizedAsOf = DateTime(asOf.year, asOf.month, asOf.day);
    return _changes.watchChanges().asyncMap(
      (_) => _load(asOf: normalizedAsOf, liabilityAccountIds: accountIds),
    );
  }

  Future<InstallmentStatisticsReadModel> _load({
    required DateTime asOf,
    required Set<String> liabilityAccountIds,
  }) async {
    final contractLists = await Future.wait(
      liabilityAccountIds.map(_installments.listContractsByLiabilityAccount),
    );
    final scheduleLists = await Future.wait(
      liabilityAccountIds.map(_installments.listSchedulesByLiabilityAccount),
    );
    final billLists = await Future.wait(
      liabilityAccountIds.map(_bills.listBillsByAccount),
    );
    final activeContracts = [
      for (final contracts in contractLists)
        for (final contract in contracts)
          if (contract.status == InstallmentContractStatus.active) contract,
    ];
    final schedulesByContract = <String, List<InstallmentSchedule>>{};
    for (final schedules in scheduleLists) {
      for (final schedule in schedules) {
        (schedulesByContract[schedule.contractId] ??= []).add(schedule);
      }
    }
    final outstandingBillItems = [
      for (final bills in billLists)
        for (final bill in bills)
          for (final item in bill.items)
            if (item.scheduleId != null && _isOutstandingBillItem(item.status))
              item,
    ];
    final allocatedByItemId = await _repayments.aggregateItemsByBillItemIds(
      outstandingBillItems.map((item) => item.id),
    );
    final remainingByScheduleId = <String, _ScheduleRemaining>{};
    for (final item in outstandingBillItems) {
      final remaining = _debtBuckets.remainingAmountsForBillItem(
        item,
        allocated: allocatedByItemId[item.id] ?? RepaymentAmountBreakdown.zero,
      );
      final scheduleId = item.scheduleId!;
      (remainingByScheduleId[scheduleId] ??= _ScheduleRemaining.zero()).add(
        _ScheduleRemaining(
          principalMinor: remaining.principalMinor,
          interestMinor: remaining.interestMinor,
          feeMinor: remaining.feeMinor,
          totalMinor: remaining.totalMinor,
        ),
      );
    }

    final contracts = <InstallmentContractStatisticsReadModel>[];
    final monthlyCashflow = <DateTime, _ScheduleRemaining>{};
    var remainingPrincipalMinor = 0;
    var remainingInterestMinor = 0;
    var remainingTotalMinor = 0;
    var overdueTotalMinor = 0;
    for (final contract in activeContracts) {
      final schedules = schedulesByContract[contract.id] ?? const [];
      var contractPrincipalMinor = 0;
      var contractInterestMinor = 0;
      var contractTotalMinor = 0;
      for (final schedule in schedules) {
        if (!_isOutstandingSchedule(schedule.status)) continue;
        final remaining =
            remainingByScheduleId[schedule.id] ??
            _ScheduleRemaining.fromSchedule(schedule);
        if (remaining.totalMinor <= 0) continue;
        contractPrincipalMinor += remaining.principalMinor;
        contractInterestMinor += remaining.interestMinor;
        contractTotalMinor += remaining.totalMinor;
        if (schedule.expectedRepaymentDate.isBefore(asOf)) {
          overdueTotalMinor += remaining.totalMinor;
          continue;
        }
        final month = DateTime(
          schedule.expectedRepaymentDate.year,
          schedule.expectedRepaymentDate.month,
        );
        (monthlyCashflow[month] ??= _ScheduleRemaining.zero()).add(remaining);
      }
      if (contractTotalMinor <= 0) continue;
      remainingPrincipalMinor += contractPrincipalMinor;
      remainingInterestMinor += contractInterestMinor;
      remainingTotalMinor += contractTotalMinor;
      contracts.add(
        InstallmentContractStatisticsReadModel(
          contractId: contract.id,
          contractName: contract.name,
          liabilityAccountId: contract.liabilityAccountId,
          remainingPrincipal: Money(minorUnits: contractPrincipalMinor),
          remainingInterest: Money(minorUnits: contractInterestMinor),
          remainingTotal: Money(minorUnits: contractTotalMinor),
          xirr: _xirr(contract, schedules),
        ),
      );
    }

    return InstallmentStatisticsReadModel(
      asOf: asOf,
      contracts: List.unmodifiable(contracts),
      remainingPrincipal: Money(minorUnits: remainingPrincipalMinor),
      remainingInterest: Money(minorUnits: remainingInterestMinor),
      remainingTotal: Money(minorUnits: remainingTotalMinor),
      overdueTotal: Money(minorUnits: overdueTotalMinor),
      monthlyCashflow: _continuousMonths(asOf, monthlyCashflow),
    );
  }

  double? _xirr(
    InstallmentContract contract,
    List<InstallmentSchedule> schedules,
  ) {
    final result = _calculator.compute(
      principal: contract.principal,
      borrowingDate: contract.borrowingDate,
      plan: [
        for (final schedule in schedules)
          InstallmentSchedulePlanEntry(
            periodNo: schedule.periodNo,
            expectedRepaymentDate: schedule.expectedRepaymentDate,
            expectedPrincipal: schedule.expectedPrincipal,
            expectedInterest: schedule.expectedInterest,
            expectedFee: schedule.expectedFee,
          ),
      ],
    );
    return result.unavailableReason == null ? result.xirr : null;
  }

  List<InstallmentMonthlyStatisticsReadModel> _continuousMonths(
    DateTime asOf,
    Map<DateTime, _ScheduleRemaining> monthlyCashflow,
  ) {
    if (monthlyCashflow.isEmpty) return const [];
    final start = DateTime(asOf.year, asOf.month);
    final lastMonth = monthlyCashflow.keys.reduce(
      (left, right) => left.isAfter(right) ? left : right,
    );
    return List.unmodifiable([
      for (
        var month = start;
        !month.isAfter(lastMonth);
        month = DateTime(month.year, month.month + 1)
      )
        (monthlyCashflow[month] ?? _ScheduleRemaining.zero()).toReadModel(
          month,
        ),
    ]);
  }

  bool _isOutstandingSchedule(InstallmentScheduleStatus status) =>
      status == InstallmentScheduleStatus.pending ||
      status == InstallmentScheduleStatus.partiallyPaid;

  bool _isOutstandingBillItem(BillItemStatus status) =>
      status == BillItemStatus.pending ||
      status == BillItemStatus.partiallyPaid;
}

class _ScheduleRemaining {
  _ScheduleRemaining({
    required this.principalMinor,
    required this.interestMinor,
    required this.feeMinor,
    required this.totalMinor,
  });

  static _ScheduleRemaining zero() => _ScheduleRemaining(
    principalMinor: 0,
    interestMinor: 0,
    feeMinor: 0,
    totalMinor: 0,
  );

  factory _ScheduleRemaining.fromSchedule(InstallmentSchedule schedule) {
    return _ScheduleRemaining(
      principalMinor: schedule.expectedPrincipal.minorUnits,
      interestMinor: schedule.expectedInterest.minorUnits,
      feeMinor: schedule.expectedFee.minorUnits,
      totalMinor:
          schedule.expectedPrincipal.minorUnits +
          schedule.expectedInterest.minorUnits +
          schedule.expectedFee.minorUnits,
    );
  }

  int principalMinor;
  int interestMinor;
  int feeMinor;
  int totalMinor;

  void add(_ScheduleRemaining other) {
    principalMinor += other.principalMinor;
    interestMinor += other.interestMinor;
    feeMinor += other.feeMinor;
    totalMinor += other.totalMinor;
  }

  InstallmentMonthlyStatisticsReadModel toReadModel(DateTime month) {
    return InstallmentMonthlyStatisticsReadModel(
      month: month,
      principal: Money(minorUnits: principalMinor),
      interest: Money(minorUnits: interestMinor),
      fee: Money(minorUnits: feeMinor),
      total: Money(minorUnits: totalMinor),
    );
  }
}
