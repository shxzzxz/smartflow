import '../../../../core/money/money.dart';
import '../../../../domain/credit/service/installment/installment_metrics.dart'
    as domain;

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

  factory ContractMetrics.fromDomain(domain.ContractMetrics result) {
    return ContractMetrics(
      monthlyIrr: result.monthlyIrr,
      nominalApr: result.nominalApr,
      effectiveApr: result.effectiveApr,
      totalRepayment: result.totalRepayment,
      totalInterest: result.totalInterest,
      totalFee: result.totalFee,
      converged: result.converged,
      unavailableReason: switch (result.unavailableReason) {
        null => null,
        domain.ContractMetricsUnavailableReason.principalNotConserved =>
          ContractMetricsUnavailableReason.principalNotConserved,
        domain.ContractMetricsUnavailableReason.insufficientCashflows =>
          ContractMetricsUnavailableReason.insufficientCashflows,
        domain.ContractMetricsUnavailableReason.noRateSolution =>
          ContractMetricsUnavailableReason.noRateSolution,
      },
    );
  }

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
