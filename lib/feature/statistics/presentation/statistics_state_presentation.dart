import '../../../application/credit/credit_query_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import 'statistics_presentation.dart';

class StatisticsStatePresentation {
  const StatisticsStatePresentation({
    required this.asOf,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.assetAccounts,
    required this.liabilityAccounts,
  });

  final DateTime asOf;
  final Money totalAssets;
  final Money totalLiabilities;
  final List<StatisticsBreakdownItem> assetAccounts;
  final List<StatisticsBreakdownItem> liabilityAccounts;
}

enum StatisticsInstallmentCompositionMetric { principal, total }

enum StatisticsInstallmentCashflowHorizon { sixMonths, oneYear, all }

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
    required this.total,
  });

  final DateTime month;
  final Money principal;
  final Money interest;
  final Money fee;
  final Money total;

  Money get interestAndFee =>
      Money(minorUnits: interest.minorUnits + fee.minorUnits);
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
    totalAssets: balance.comparison.current.assets,
    totalLiabilities: balance.comparison.current.liabilities,
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
  required InstallmentStatisticsReadModel statistics,
  required Map<String, Account> accountsById,
}) {
  final sortedCompositionItems = sortStatisticsInstallmentCompositionItems([
    for (final contract in statistics.contracts)
      StatisticsInstallmentCompositionItem(
        contractId: contract.contractId,
        contractName: contract.contractName,
        accountName: accountsById[contract.liabilityAccountId]?.name ?? '未知账户',
        remainingPrincipal: contract.remainingPrincipal,
        remainingInterest: contract.remainingInterest,
        remainingTotal: contract.remainingTotal,
        xirr: contract.xirr,
      ),
  ], StatisticsInstallmentCompositionMetric.principal);
  return StatisticsInstallmentsPresentation(
    asOf: statistics.asOf,
    compositionItems: sortedCompositionItems,
    remainingPrincipal: statistics.remainingPrincipal,
    remainingInterest: statistics.remainingInterest,
    remainingTotal: statistics.remainingTotal,
    cashflowMonths: List.unmodifiable([
      for (final month in statistics.monthlyCashflow)
        StatisticsInstallmentCashflowMonth(
          month: month.month,
          principal: month.principal,
          interest: month.interest,
          fee: month.fee,
          total: month.total,
        ),
    ]),
    overdueTotal: statistics.overdueTotal,
  );
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
