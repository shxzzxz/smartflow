import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_query_api.dart';

part 'installment_query_providers.g.dart';

@riverpod
Future<List<InstallmentContract>> installmentContractsByAccount(
  Ref ref,
  String accountId,
) {
  return ref
      .watch(installmentQueryServiceProvider)
      .listContractsByLiabilityAccount(accountId);
}

@riverpod
Future<InstallmentContract?> installmentContract(Ref ref, String contractId) {
  return ref.watch(installmentQueryServiceProvider).findContract(contractId);
}

@riverpod
Future<List<InstallmentSchedule>> installmentSchedules(
  Ref ref,
  String contractId,
) {
  return ref.watch(installmentQueryServiceProvider).listSchedules(contractId);
}

/// 提供 metrics 模块所需的 RepaymentCashflow 列表。
/// 读取 v2 repayment 聚合；有账务交易时用交易时间，无交易时用记录创建时间。
@riverpod
Future<List<RepaymentCashflow>> installmentRepaymentCashflows(
  Ref ref,
  String contractId,
) async {
  final repayments = await ref
      .watch(repaymentRepositoryProvider)
      .listByTarget(RepaymentTargetType.contract, contractId);
  final queryService = ref.watch(transactionQueryServiceProvider);
  final result = <RepaymentCashflow>[];
  for (final repayment in repayments) {
    final view =
        repayment.rootTransactionId == null
            ? null
            : await queryService.findTransactionDetail(
              repayment.rootTransactionId!,
            );
    final allocated = repayment.totalAllocated();
    result.add(
      RepaymentCashflow(
        id: repayment.id,
        transactionId: repayment.rootTransactionId,
        repaymentType: repayment.repaymentType,
        occurredAt:
            view?.transaction.occurredAt ??
            repayment.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0),
        principal: allocated.principal,
        interest: allocated.interest,
        fee: allocated.fee,
      ),
    );
  }
  return result;
}

/// 按当前合同计划与合同级提前还款计算合同指标。
@riverpod
Future<ContractMetrics> installmentMetrics(Ref ref, String contractId) async {
  final contract = await ref.watch(
    installmentContractProvider(contractId).future,
  );
  final schedules = await ref.watch(
    installmentSchedulesProvider(contractId).future,
  );
  final repayments = await ref.watch(
    installmentRepaymentCashflowsProvider(contractId).future,
  );
  if (contract == null) {
    throw StateError('Contract $contractId not found');
  }
  const calc = InstallmentMetricsCalculator();
  return calc.compute(
    contract: contract,
    schedules: schedules,
    repayments: repayments,
  );
}
