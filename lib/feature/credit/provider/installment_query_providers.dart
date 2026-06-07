import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_query_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';

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
Future<List<InstallmentRepayment>> installmentRepayments(
  Ref ref,
  String contractId,
) {
  return ref.watch(installmentQueryServiceProvider).listRepayments(contractId);
}

/// 提供 metrics 模块所需的 RepaymentCashflow 列表。
/// 内部读取每张 repayment 关联交易的 details，把本金 / 利息 / 手续费拆出。
@riverpod
Future<List<RepaymentCashflow>> installmentRepaymentCashflows(
  Ref ref,
  String contractId,
) async {
  final repayments = await ref.watch(
    installmentRepaymentsProvider(contractId).future,
  );
  final queryService = ref.watch(transactionQueryServiceProvider);
  final result = <RepaymentCashflow>[];
  for (final repayment in repayments) {
    final view = await queryService.findTransactionDetail(
      repayment.transactionId,
    );
    if (view == null) continue;
    int principalMinor = 0;
    int interestMinor = 0;
    int feeMinor = 0;
    for (final detail in view.details) {
      switch (detail.type) {
        case TransactionDetailType.repaymentPrincipal:
          principalMinor = principalMinor + detail.amount.minorUnits;
        case TransactionDetailType.repaymentInterest:
          interestMinor = interestMinor + detail.amount.minorUnits;
        case TransactionDetailType.repaymentFee:
          feeMinor = feeMinor + detail.amount.minorUnits;
        case TransactionDetailType.repaymentDiscount:
          principalMinor = principalMinor - detail.amount.minorUnits;
        default:
          break;
      }
    }
    result.add(
      RepaymentCashflow(
        id: repayment.id,
        transactionId: repayment.transactionId,
        repaymentType: repayment.repaymentType,
        scheduleId: repayment.scheduleId,
        occurredAt: view.transaction.occurredAt,
        principal: Money(minorUnits: principalMinor),
        interest: Money(minorUnits: interestMinor),
        fee: Money(minorUnits: feeMinor),
      ),
    );
  }
  return result;
}

/// 计算 designed / actual 两个视图的 metrics 一并返回，UI 选择展示。
@riverpod
Future<({ContractMetrics designed, ContractMetrics actual})> installmentMetrics(
  Ref ref,
  String contractId,
) async {
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
  return (
    designed: calc.compute(
      contract: contract,
      schedules: schedules,
      repayments: repayments,
    ),
    actual: calc.compute(
      contract: contract,
      schedules: schedules,
      repayments: repayments,
      view: ContractMetricsView.actual,
    ),
  );
}
