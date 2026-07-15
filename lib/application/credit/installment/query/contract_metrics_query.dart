import '../../../../core/error/app_exception.dart';
import '../../../../domain/credit/port/installment_repository.dart';
import '../../../../domain/credit/service/installment/installment_metrics.dart'
    as domain;
import '../../../../domain/credit/valobj/credit_error_code.dart';
import 'contract_metrics_read_model.dart';

abstract interface class ContractMetricsQuery {
  Future<ContractMetrics> getContractMetrics(String contractId);
}

class ContractMetricsQueryImpl implements ContractMetricsQuery {
  const ContractMetricsQueryImpl({
    required InstallmentRepository installments,
    domain.InstallmentMetricsCalculator calculator =
        const domain.InstallmentMetricsCalculator(),
  }) : _installments = installments,
       _calculator = calculator;

  final InstallmentRepository _installments;
  final domain.InstallmentMetricsCalculator _calculator;

  @override
  Future<ContractMetrics> getContractMetrics(String contractId) async {
    final contract = await _installments.findContract(contractId);
    if (contract == null) {
      throw BusinessException(CreditErrorCode.contractNotFound);
    }
    final schedules = await _installments.listSchedules(contractId);
    final result = _calculator.compute(
      contract: contract,
      schedules: schedules,
    );
    return ContractMetrics(
      monthlyIrr: result.monthlyIrr,
      nominalApr: result.nominalApr,
      effectiveApr: result.effectiveApr,
      totalRepayment: result.totalRepayment,
      totalInterest: result.totalInterest,
      totalFee: result.totalFee,
      converged: result.converged,
      unavailableReason: _mapUnavailableReason(result.unavailableReason),
    );
  }

  ContractMetricsUnavailableReason? _mapUnavailableReason(
    domain.ContractMetricsUnavailableReason? reason,
  ) {
    return switch (reason) {
      null => null,
      domain.ContractMetricsUnavailableReason.principalNotConserved =>
        ContractMetricsUnavailableReason.principalNotConserved,
      domain.ContractMetricsUnavailableReason.insufficientCashflows =>
        ContractMetricsUnavailableReason.insufficientCashflows,
      domain.ContractMetricsUnavailableReason.noRateSolution =>
        ContractMetricsUnavailableReason.noRateSolution,
    };
  }
}
