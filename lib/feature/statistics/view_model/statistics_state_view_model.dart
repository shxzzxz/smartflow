import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_query_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/time/month_key.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../presentation/statistics_state_presentation.dart';

part 'statistics_state_view_model.g.dart';

@riverpod
Stream<BalanceReport> statisticsCurrentBalanceReport(Ref ref, DateTime asOf) {
  final cutoff = DateTime(asOf.year, asOf.month, asOf.day + 1);
  return ref
      .watch(financialMetricsServiceProvider)
      .watchBalanceReport(
        BalanceReportQuery(
          month: MonthKey.fromDate(asOf),
          asOfExclusive: cutoff,
          trendMonths: 0,
        ),
      );
}

@riverpod
StatisticsStateContentState statisticsStateContent(Ref ref, DateTime asOf) {
  final balance = ref.watch(statisticsCurrentBalanceReportProvider(asOf));
  final accounts = ref.watch(accountsByIdProvider);

  for (final value in [balance, accounts]) {
    if (value case AsyncError()) {
      return const StatisticsStateContentState.error(
        message: '当前状态加载失败，请稍后重试。',
      );
    }
  }

  final balanceValue = balance.value;
  final accountValues = accounts.value;
  if (balanceValue == null || accountValues == null) {
    return const StatisticsStateContentState.loading();
  }

  return StatisticsStateContentState.loaded(
    presentation: buildStatisticsStatePresentation(
      asOf: asOf,
      balance: balanceValue,
      accountsById: accountValues,
    ),
  );
}

@riverpod
Future<StatisticsInstallmentsPresentation> statisticsInstallments(
  Ref ref,
  DateTime asOf,
) async {
  final accounts = await ref.watch(accountsByIdProvider.future);
  final installmentQuery = ref.watch(installmentQueryServiceProvider);
  final metricsQuery = ref.watch(contractMetricsQueryProvider);
  final liabilityAccounts = accounts.values.where(
    (account) => account.type == AccountType.liability,
  );
  final contractLists = await Future.wait(
    liabilityAccounts.map(
      (account) => installmentQuery.listContractsByLiabilityAccount(account.id),
    ),
  );
  final activeContracts = [
    for (final contracts in contractLists)
      for (final contract in contracts)
        if (contract.status == InstallmentContractStatus.active) contract,
  ];
  final snapshots = await Future.wait([
    for (final contract in activeContracts)
      _installmentSnapshot(
        contract: contract,
        accountName: accounts[contract.liabilityAccountId]?.name ?? '未知账户',
        installmentQuery: installmentQuery,
        metricsQuery: metricsQuery,
      ),
  ]);
  return buildStatisticsInstallmentsPresentation(
    asOf: asOf,
    contracts: snapshots,
  );
}

Future<StatisticsInstallmentSnapshot> _installmentSnapshot({
  required InstallmentContractReadModel contract,
  required String accountName,
  required InstallmentQueryService installmentQuery,
  required ContractMetricsQuery metricsQuery,
}) async {
  final schedules = await installmentQuery.listSchedules(contract.id);
  final metrics = await metricsQuery.getContractMetrics(contract.id);
  return StatisticsInstallmentSnapshot(
    contractId: contract.id,
    contractName: contract.name,
    accountName: accountName,
    schedules: schedules,
    metrics: metrics,
  );
}

sealed class StatisticsStateContentState {
  const StatisticsStateContentState();

  const factory StatisticsStateContentState.loading() =
      StatisticsStateContentLoading;

  const factory StatisticsStateContentState.error({required String message}) =
      StatisticsStateContentError;

  const factory StatisticsStateContentState.loaded({
    required StatisticsStatePresentation presentation,
  }) = StatisticsStateContentLoaded;
}

final class StatisticsStateContentLoading extends StatisticsStateContentState {
  const StatisticsStateContentLoading();
}

final class StatisticsStateContentError extends StatisticsStateContentState {
  const StatisticsStateContentError({required this.message});

  final String message;
}

final class StatisticsStateContentLoaded extends StatisticsStateContentState {
  const StatisticsStateContentLoaded({required this.presentation});

  final StatisticsStatePresentation presentation;
}
