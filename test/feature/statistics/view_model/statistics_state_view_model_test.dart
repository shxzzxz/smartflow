import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/statistics/view_model/statistics_state_view_model.dart';

void main() {
  test(
    'maps the current installment read model into page presentation',
    () async {
      final asOf = DateTime(2026, 10, 18);
      final container = ProviderContainer(
        overrides: [
          accountsByIdProvider.overrideWith(
            (ref) => Stream.value({
              'loan-account': Account(
                id: 'loan-account',
                name: '消费贷账户',
                type: AccountType.liability,
                balance: const Money(minorUnits: 0),
              ),
            }),
          ),
          installmentStatisticsQueryProvider.overrideWithValue(
            _FakeInstallmentStatisticsQuery(
              InstallmentStatisticsReadModel(
                asOf: asOf,
                contracts: const [
                  InstallmentContractStatisticsReadModel(
                    contractId: 'contract',
                    contractName: '分期合同',
                    liabilityAccountId: 'loan-account',
                    remainingPrincipal: Money(minorUnits: 90000),
                    remainingInterest: Money(minorUnits: 900),
                    remainingTotal: Money(minorUnits: 91000),
                    xirr: .08,
                  ),
                ],
                remainingPrincipal: const Money(minorUnits: 90000),
                remainingInterest: const Money(minorUnits: 900),
                remainingTotal: const Money(minorUnits: 91000),
                overdueTotal: const Money(minorUnits: 0),
                monthlyCashflow: const [],
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final provider = statisticsInstallmentsProvider(asOf);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);

      final presentation = await container.read(provider.future);

      expect(presentation.compositionItems.single.accountName, '消费贷账户');
      expect(presentation.remainingPrincipal, const Money(minorUnits: 90000));
      expect(presentation.remainingTotal, const Money(minorUnits: 91000));
    },
  );
}

class _FakeInstallmentStatisticsQuery implements InstallmentStatisticsQuery {
  const _FakeInstallmentStatisticsQuery(this.report);

  final InstallmentStatisticsReadModel report;

  @override
  Stream<InstallmentStatisticsReadModel> watchStatistics({
    required DateTime asOf,
    required Set<String> liabilityAccountIds,
  }) {
    return Stream.value(report);
  }
}
