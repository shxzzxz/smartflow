import '../../../application/credit/credit_query_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import 'statistics_presentation.dart';

class StatisticsStatePresentation {
  const StatisticsStatePresentation({
    required this.asOf,
    required this.assetAccounts,
    required this.liabilityAccounts,
  });

  final DateTime asOf;
  final List<StatisticsBreakdownItem> assetAccounts;
  final List<StatisticsBreakdownItem> liabilityAccounts;
}

enum StatisticsInstallmentCompositionMetric { principal, total }

enum StatisticsInstallmentCashflowHorizon { sixMonths, oneYear, all }

class StatisticsInstallmentSnapshot {
  const StatisticsInstallmentSnapshot({
    required this.contractId,
    required this.contractName,
    required this.accountName,
    required this.schedules,
    required this.metrics,
  });

  final String contractId;
  final String contractName;
  final String accountName;
  final List<InstallmentScheduleReadModel> schedules;
  final ContractMetrics metrics;
}

class StatisticsInstallmentsPresentation {
  const StatisticsInstallmentsPresentation({
    required this.asOf,
    required this.compositionItems,
    required this.remainingPrincipal,
    required this.remainingInterest,
    required this.remainingTotal,
    required this.cashflowMonths,
    required this.overdueTotal,
  });

  final DateTime asOf;
  final List<StatisticsInstallmentCompositionItem> compositionItems;
  final Money remainingPrincipal;
  final Money remainingInterest;
  final Money remainingTotal;
  final List<StatisticsInstallmentCashflowMonth> cashflowMonths;
  final Money overdueTotal;
}

class StatisticsInstallmentCompositionItem {
  const StatisticsInstallmentCompositionItem({
    required this.contractId,
    required this.contractName,
    required this.accountName,
    required this.remainingPrincipal,
    required this.remainingInterest,
    required this.remainingTotal,
    required this.xirr,
  });

  final String contractId;
  final String contractName;
  final String accountName;
  final Money remainingPrincipal;
  final Money remainingInterest;
  final Money remainingTotal;
  final double? xirr;
}

class StatisticsInstallmentCashflowMonth {
  const StatisticsInstallmentCashflowMonth({
    required this.month,
    required this.principal,
    required this.interest,
    required this.fee,
  });

  final DateTime month;
  final Money principal;
  final Money interest;
  final Money fee;

  Money get interestAndFee =>
      Money(minorUnits: interest.minorUnits + fee.minorUnits);
  Money get total => Money(
    minorUnits: principal.minorUnits + interest.minorUnits + fee.minorUnits,
  );
}

class _InstallmentCashflowAccumulator {
  var principalMinor = 0;
  var interestMinor = 0;
  var feeMinor = 0;

  void add(InstallmentScheduleReadModel schedule) {
    principalMinor += schedule.expectedPrincipal.minorUnits;
    interestMinor += schedule.expectedInterest.minorUnits;
    feeMinor += schedule.expectedFee.minorUnits;
  }

  StatisticsInstallmentCashflowMonth toPresentation(DateTime month) {
    return StatisticsInstallmentCashflowMonth(
      month: month,
      principal: Money(minorUnits: principalMinor),
      interest: Money(minorUnits: interestMinor),
      fee: Money(minorUnits: feeMinor),
    );
  }
}

List<StatisticsInstallmentCompositionItem>
sortStatisticsInstallmentCompositionItems(
  List<StatisticsInstallmentCompositionItem> items,
  StatisticsInstallmentCompositionMetric metric,
) {
  final sorted = [...items];
  sorted.sort((left, right) {
    final leftValue = metric == StatisticsInstallmentCompositionMetric.principal
        ? left.remainingPrincipal.minorUnits
        : left.remainingTotal.minorUnits;
    final rightValue =
        metric == StatisticsInstallmentCompositionMetric.principal
        ? right.remainingPrincipal.minorUnits
        : right.remainingTotal.minorUnits;
    final valueOrder = rightValue.compareTo(leftValue);
    if (valueOrder != 0) return valueOrder;
    final accountOrder = left.accountName.compareTo(right.accountName);
    if (accountOrder != 0) return accountOrder;
    return left.contractName.compareTo(right.contractName);
  });
  return List.unmodifiable(sorted);
}

StatisticsStatePresentation buildStatisticsStatePresentation({
  required DateTime asOf,
  required BalanceReport balance,
  required Map<String, Account> accountsById,
}) {
  final normalizedAsOf = DateTime(asOf.year, asOf.month, asOf.day);
  return StatisticsStatePresentation(
    asOf: normalizedAsOf,
    assetAccounts: _accountBreakdown(
      balance.accounts,
      accountsById,
      AccountType.asset,
    ),
    liabilityAccounts: _accountBreakdown(
      balance.accounts,
      accountsById,
      AccountType.liability,
    ),
  );
}

StatisticsInstallmentsPresentation buildStatisticsInstallmentsPresentation({
  required DateTime asOf,
  required List<StatisticsInstallmentSnapshot> contracts,
}) {
  final normalizedAsOf = DateTime(asOf.year, asOf.month, asOf.day);
  final compositionItems = <StatisticsInstallmentCompositionItem>[];
  final monthlyCashflow = <DateTime, _InstallmentCashflowAccumulator>{};
  var overdueTotalMinor = 0;

  for (final contract in contracts) {
    final outstandingSchedules =
        contract.schedules
            .where(
              (schedule) =>
                  schedule.status == InstallmentScheduleStatus.pending ||
                  schedule.status == InstallmentScheduleStatus.partiallyPaid,
            )
            .toList()
          ..sort(
            (left, right) => left.expectedRepaymentDate.compareTo(
              right.expectedRepaymentDate,
            ),
          );
    if (outstandingSchedules.isEmpty) continue;

    var remainingPrincipalMinor = 0;
    var remainingInterestMinor = 0;
    var remainingFeeMinor = 0;
    for (final schedule in outstandingSchedules) {
      remainingPrincipalMinor += schedule.expectedPrincipal.minorUnits;
      remainingInterestMinor += schedule.expectedInterest.minorUnits;
      remainingFeeMinor += schedule.expectedFee.minorUnits;
      final repaymentDate = schedule.expectedRepaymentDate;
      if (repaymentDate.isBefore(normalizedAsOf)) {
        overdueTotalMinor +=
            schedule.expectedPrincipal.minorUnits +
            schedule.expectedInterest.minorUnits +
            schedule.expectedFee.minorUnits;
        continue;
      }
      final month = DateTime(repaymentDate.year, repaymentDate.month);
      (monthlyCashflow[month] ??= _InstallmentCashflowAccumulator()).add(
        schedule,
      );
    }

    compositionItems.add(
      StatisticsInstallmentCompositionItem(
        contractId: contract.contractId,
        contractName: contract.contractName,
        accountName: contract.accountName,
        remainingPrincipal: Money(minorUnits: remainingPrincipalMinor),
        remainingInterest: Money(minorUnits: remainingInterestMinor),
        remainingTotal: Money(
          minorUnits:
              remainingPrincipalMinor +
              remainingInterestMinor +
              remainingFeeMinor,
        ),
        xirr: contract.metrics.isAvailable ? contract.metrics.xirr : null,
      ),
    );
  }

  final sortedCompositionItems = sortStatisticsInstallmentCompositionItems(
    compositionItems,
    StatisticsInstallmentCompositionMetric.principal,
  );
  return StatisticsInstallmentsPresentation(
    asOf: normalizedAsOf,
    compositionItems: sortedCompositionItems,
    remainingPrincipal: Money(
      minorUnits: sortedCompositionItems.fold(
        0,
        (sum, item) => sum + item.remainingPrincipal.minorUnits,
      ),
    ),
    remainingInterest: Money(
      minorUnits: sortedCompositionItems.fold(
        0,
        (sum, item) => sum + item.remainingInterest.minorUnits,
      ),
    ),
    remainingTotal: Money(
      minorUnits: sortedCompositionItems.fold(
        0,
        (sum, item) => sum + item.remainingTotal.minorUnits,
      ),
    ),
    cashflowMonths: _continuousCashflowMonths(normalizedAsOf, monthlyCashflow),
    overdueTotal: Money(minorUnits: overdueTotalMinor),
  );
}

List<StatisticsInstallmentCashflowMonth> _continuousCashflowMonths(
  DateTime asOf,
  Map<DateTime, _InstallmentCashflowAccumulator> monthlyCashflow,
) {
  if (monthlyCashflow.isEmpty) return const [];
  final start = DateTime(asOf.year, asOf.month);
  final lastMonth = monthlyCashflow.keys.reduce(
    (left, right) => left.isAfter(right) ? left : right,
  );
  final months = <StatisticsInstallmentCashflowMonth>[];
  for (
    var month = start;
    !month.isAfter(lastMonth);
    month = DateTime(month.year, month.month + 1)
  ) {
    months.add(
      (monthlyCashflow[month] ?? _InstallmentCashflowAccumulator())
          .toPresentation(month),
    );
  }
  return List.unmodifiable(months);
}

List<StatisticsBreakdownItem> _accountBreakdown(
  List<AccountMetric> metrics,
  Map<String, Account> accountsById,
  AccountType type,
) {
  final items =
      [
        for (final metric in metrics)
          if (metric.accountType == type)
            StatisticsBreakdownItem(
              id: metric.accountId,
              title: accountsById[metric.accountId]?.name ?? '已归档账户',
              accountType: type,
              amount: metric.amount,
              progress: 0,
            ),
      ]..sort(
        (left, right) => right.amount.minorUnits.abs().compareTo(
          left.amount.minorUnits.abs(),
        ),
      );
  final maxMinor = items
      .map((item) => item.amount.minorUnits.abs())
      .fold<int>(0, (max, value) => value > max ? value : max);
  return [
    for (final item in items)
      item.copyWith(
        progress: maxMinor == 0 ? 0 : item.amount.minorUnits.abs() / maxMinor,
      ),
  ];
}
