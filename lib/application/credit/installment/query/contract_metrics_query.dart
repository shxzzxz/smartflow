import '../../../../core/error/app_exception.dart';
import '../../../../domain/credit/port/installment_repository.dart';
import '../../../../domain/credit/service/installment/installment_metrics.dart'
    as domain;
import '../../../../domain/credit/service/installment/installment_plan_engine.dart';
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
    return ContractMetrics.fromDomain(result);
  }
}
