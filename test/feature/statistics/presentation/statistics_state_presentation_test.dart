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
    };
    final presentation = buildStatisticsStatePresentation(
      asOf: DateTime(2026, 10, 18),
      balance: BalanceReport(
        comparison: const BalanceSheetComparison(
          current: BalanceSheetSnapshot(
            assets: Money(minorUnits: 10000),
            liabilities: Money(minorUnits: 2000),
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
        ],
      ),
      accountsById: accountsById,
    );
    expect(presentation.assetAccounts.map((item) => item.title), ['现金', '应收']);
    expect(presentation.liabilityAccounts.single.title, '贷款');
  });

  test(
    'builds installment composition and cashflow from outstanding periods',
    () {
      final presentation = buildStatisticsInstallmentsPresentation(
        asOf: DateTime(2026, 10, 18),
        contracts: [
          _snapshot(
            contractId: 'high-rate',
            contractName: '消费贷',
            xirr: .18,
            schedules: [
              _schedule(
                contractId: 'high-rate',
                periodNo: 1,
                date: DateTime(2026, 10, 17),
                principalMinor: 1000,
                interestMinor: 100,
              ),
              _schedule(
                contractId: 'high-rate',
                periodNo: 2,
                date: DateTime(2026, 11, 15),
                principalMinor: 9000,
                interestMinor: 900,
                feeMinor: 100,
              ),
              _schedule(
                contractId: 'high-rate',
                periodNo: 3,
                date: DateTime(2026, 12, 15),
                principalMinor: 8000,
                interestMinor: 8000,
                status: InstallmentScheduleStatus.paid,
              ),
            ],
          ),
          _snapshot(
            contractId: 'large-balance',
            contractName: '房贷',
            xirr: .05,
            schedules: [
              _schedule(
                contractId: 'large-balance',
                periodNo: 1,
                date: DateTime(2026, 12, 1),
                principalMinor: 50000,
                interestMinor: 2500,
              ),
            ],
          ),
        ],
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
    },
  );
}

Account _account(String id, String name, AccountType type) {
  return Account(
    id: id,
    name: name,
    type: type,
    balance: const Money(minorUnits: 0),
  );
}

StatisticsInstallmentSnapshot _snapshot({
  required String contractId,
  required String contractName,
  required double xirr,
  required List<InstallmentScheduleReadModel> schedules,
}) {
  return StatisticsInstallmentSnapshot(
    contractId: contractId,
    contractName: contractName,
    accountName: '贷款账户',
    schedules: schedules,
    metrics: ContractMetrics(
      monthlyIrr: 0,
      nominalApr: 0,
      xirr: xirr,
      totalRepayment: const Money(minorUnits: 0),
      totalInterest: const Money(minorUnits: 0),
      totalFee: const Money(minorUnits: 0),
      converged: true,
      unavailableReason: null,
    ),
  );
}

InstallmentScheduleReadModel _schedule({
  required String contractId,
  required int periodNo,
  required DateTime date,
  required int principalMinor,
  required int interestMinor,
  int feeMinor = 0,
  InstallmentScheduleStatus status = InstallmentScheduleStatus.pending,
}) {
  return InstallmentScheduleReadModel(
    id: '$contractId-$periodNo',
    contractId: contractId,
    periodNo: periodNo,
    expectedRepaymentDate: date,
    expectedPrincipal: Money(minorUnits: principalMinor),
    expectedInterest: Money(minorUnits: interestMinor),
    expectedFee: Money(minorUnits: feeMinor),
    status: status,
    createdAt: DateTime(2026),
  );
}
