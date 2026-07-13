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

@riverpod
Future<List<ContractRepayment>> installmentRepayments(
  Ref ref,
  String contractId,
) {
  return ref
      .watch(contractRepaymentQueryProvider)
      .listContractRepayments(contractId);
}

/// 按合同与全部还款计划计算合同指标。
@riverpod
Future<ContractMetrics> installmentMetrics(Ref ref, String contractId) {
  return ref.watch(contractMetricsQueryProvider).getContractMetrics(contractId);
}
