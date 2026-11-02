import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_query_api.dart';

part 'installment_query_providers.g.dart';

@riverpod
Future<List<InstallmentDTO>> installmentsByAccount(Ref ref, String accountId) {
  return ref
      .watch(installmentQueryServiceProvider)
      .listInstallmentsByLiabilityAccount(accountId);
}

@riverpod
Future<InstallmentDTO?> installment(Ref ref, String installmentId) {
  return ref
      .watch(installmentQueryServiceProvider)
      .findInstallment(installmentId);
}

@riverpod
Future<InstallmentDetailDTO?> installmentDetail(Ref ref, String installmentId) {
  return ref
      .watch(installmentQueryServiceProvider)
      .findInstallmentDetail(installmentId);
}

@riverpod
Future<InstallmentRepricingDTO?> installmentRepricing(
  Ref ref,
  String installmentId,
) {
  return ref
      .watch(installmentQueryServiceProvider)
      .findInstallmentRepricing(installmentId);
}

@riverpod
Future<InstallmentInterestAdjustmentDTO?> installmentInterestAdjustment(
  Ref ref,
  String installmentId,
) {
  return ref
      .watch(installmentQueryServiceProvider)
      .findInstallmentInterestAdjustment(installmentId);
}

@riverpod
Future<List<ContractActivity>> installmentActivities(
  Ref ref,
  String contractId,
) {
  return ref
      .watch(contractActivityQueryProvider)
      .listContractActivities(contractId);
}

/// 按合同与全部还款计划计算合同指标。
@riverpod
Future<ContractMetrics> installmentMetrics(Ref ref, String contractId) {
  return ref.watch(contractMetricsQueryProvider).getContractMetrics(contractId);
}
