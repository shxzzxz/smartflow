import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/statistics/presentation/statistics_state_presentation.dart';

void main() {
  test('builds current account structure', () {
    final accountsById = {
      'cash': _account('cash', '现金', AccountType.asset),
      'receivable': _account('receivable', '应收', AccountType.asset),
      'loan': _account('loan', '贷款', AccountType.liability),
      'overpaid-card': _account('overpaid-card', '信用卡', AccountType.liability),
    };
    final presentation = buildStatisticsStatePresentation(
      asOf: DateTime(2026, 10, 18),
      balance: BalanceReport(
        comparison: const BalanceSheetComparison(
          current: BalanceSheetSnapshot(
            assets: Money(minorUnits: 10000),
            liabilities: Money(minorUnits: 1500),
          ),
          previous: BalanceSheetSnapshot(
            assets: Money(minorUnits: 9000),
            liabilities: Money(minorUnits: 1800),
          ),
        ),
        trend: const [],
        accounts: const [
          AccountMetric(
            accountId: 'cash',
            accountType: AccountType.asset,
            amountMinor: 7000,
          ),
          AccountMetric(
            accountId: 'receivable',
            accountType: AccountType.asset,
            amountMinor: 3000,
          ),
          AccountMetric(
            accountId: 'loan',
            accountType: AccountType.liability,
            amountMinor: 2000,
          ),
          AccountMetric(
            accountId: 'overpaid-card',
            accountType: AccountType.liability,
            amountMinor: -500,
          ),
        ],
      ),
      accountsById: accountsById,
    );
    expect(presentation.assetAccounts.map((item) => item.title), ['现金', '应收']);
    expect(presentation.liabilityAccounts.map((item) => item.title), [
      '贷款',
      '信用卡',
    ]);
    expect(presentation.totalAssets, const Money(minorUnits: 10000));
    expect(presentation.totalLiabilities, const Money(minorUnits: 1500));
  });

  test('maps application installment statistics into presentation', () {
    final presentation = buildStatisticsInstallmentsPresentation(
      statistics: InstallmentStatisticsReadModel(
        asOf: DateTime(2026, 10, 18),
        contracts: const [
          InstallmentContractStatisticsReadModel(
            contractId: 'high-rate',
            contractName: '消费贷',
            liabilityAccountId: 'loan',
            remainingPrincipal: Money(minorUnits: 10000),
            remainingInterest: Money(minorUnits: 1000),
            remainingTotal: Money(minorUnits: 11100),
            xirr: .18,
          ),
          InstallmentContractStatisticsReadModel(
            contractId: 'large-balance',
            contractName: '房贷',
            liabilityAccountId: 'loan',
            remainingPrincipal: Money(minorUnits: 50000),
            remainingInterest: Money(minorUnits: 2500),
            remainingTotal: Money(minorUnits: 52500),
            xirr: .05,
          ),
        ],
        remainingPrincipal: const Money(minorUnits: 60000),
        remainingInterest: const Money(minorUnits: 3500),
        remainingTotal: const Money(minorUnits: 63600),
        overdueTotal: const Money(minorUnits: 1100),
        monthlyCashflow: [
          InstallmentMonthlyStatisticsReadModel(
            month: DateTime(2026, 10),
            principal: Money(minorUnits: 0),
            interest: Money(minorUnits: 0),
            fee: Money(minorUnits: 0),
            total: Money(minorUnits: 0),
          ),
          InstallmentMonthlyStatisticsReadModel(
            month: DateTime(2026, 11),
            principal: Money(minorUnits: 9000),
            interest: Money(minorUnits: 900),
            fee: Money(minorUnits: 100),
            total: Money(minorUnits: 10000),
          ),
          InstallmentMonthlyStatisticsReadModel(
            month: DateTime(2026, 12),
            principal: Money(minorUnits: 50000),
            interest: Money(minorUnits: 2500),
            fee: Money(minorUnits: 0),
            total: Money(minorUnits: 52500),
          ),
        ],
      ),
      accountsById: {'loan': _account('loan', '贷款', AccountType.liability)},
    );

    expect(presentation.compositionItems.map((item) => item.contractId), [
      'large-balance',
      'high-rate',
    ]);
    expect(presentation.remainingPrincipal.minorUnits, 60000);
    expect(presentation.remainingInterest.minorUnits, 3500);
    expect(presentation.remainingTotal.minorUnits, 63600);
    expect(presentation.overdueTotal.minorUnits, 1100);
    expect(presentation.cashflowMonths, hasLength(3));
    expect(presentation.cashflowMonths.first.month, DateTime(2026, 10));
    expect(presentation.cashflowMonths[1].total.minorUnits, 10000);
    expect(presentation.cashflowMonths[2].interestAndFee.minorUnits, 2500);

    final byTotal = sortStatisticsInstallmentCompositionItems(
      presentation.compositionItems,
      StatisticsInstallmentCompositionMetric.total,
    );
    expect(byTotal.first.contractId, 'large-balance');
  });
}

Account _account(String id, String name, AccountType type) {
  return Account(
    id: id,
    name: name,
    type: type,
    balance: const Money(minorUnits: 0),
  );
}
