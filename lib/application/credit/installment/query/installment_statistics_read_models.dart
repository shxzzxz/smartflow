import '../../../../core/money/money.dart';

class InstallmentStatisticsReadModel {
  const InstallmentStatisticsReadModel({
    required this.asOf,
    required this.contracts,
    required this.remainingPrincipal,
    required this.remainingInterest,
    required this.remainingTotal,
    required this.overdueTotal,
    required this.monthlyCashflow,
  });

  final DateTime asOf;
  final List<InstallmentContractStatisticsReadModel> contracts;
  final Money remainingPrincipal;
  final Money remainingInterest;
  final Money remainingTotal;
  final Money overdueTotal;
  final List<InstallmentMonthlyStatisticsReadModel> monthlyCashflow;
}

class InstallmentContractStatisticsReadModel {
  const InstallmentContractStatisticsReadModel({
    required this.contractId,
    required this.contractName,
    required this.liabilityAccountId,
    required this.remainingPrincipal,
    required this.remainingInterest,
    required this.remainingTotal,
    required this.xirr,
  });

  final String contractId;
  final String contractName;
  final String liabilityAccountId;
  final Money remainingPrincipal;
  final Money remainingInterest;
  final Money remainingTotal;
  final double? xirr;
}

class InstallmentMonthlyStatisticsReadModel {
  const InstallmentMonthlyStatisticsReadModel({
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
