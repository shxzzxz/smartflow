import '../../../../core/money/money.dart';

enum ContractMetricsUnavailableReason {
  principalNotConserved,
  insufficientCashflows,
  noRateSolution,
}

class ContractMetrics {
  const ContractMetrics({
    required this.monthlyIrr,
    required this.nominalApr,
    required this.effectiveApr,
    required this.totalRepayment,
    required this.totalInterest,
    required this.totalFee,
    required this.converged,
    required this.unavailableReason,
  });

  final double? monthlyIrr;
  final double? nominalApr;
  final double? effectiveApr;
  final Money totalRepayment;
  final Money totalInterest;
  final Money totalFee;
  final bool converged;
  final ContractMetricsUnavailableReason? unavailableReason;

  bool get isAvailable => unavailableReason == null;
}
