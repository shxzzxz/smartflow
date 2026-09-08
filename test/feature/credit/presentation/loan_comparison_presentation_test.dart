import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/calculator/query/loan_calculator_read_model.dart';
import 'package:smartflow/application/credit/installment/query/contract_metrics_read_model.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/credit/presentation/loan_comparison_presentation.dart';
import 'package:smartflow/feature/credit/view_model/installment_terms_draft.dart';
import 'package:smartflow/feature/credit/view_model/loan_configuration_view_model.dart';

void main() {
  test(
    'keeps numeric differences in configuration-one minus configuration-two order',
    () {
      final first = _configuration(principal: 10000, xirr: .12, periods: 12);
      final second = _configuration(principal: 8000, xirr: .10, periods: 10);

      final rows = presentLoanComparison(first: first, second: second);

      expect(rows[0].difference, '20.00');
      expect(rows[3].difference, '2.00%');
      expect(rows[4].difference, '20.00');
      expect(rows[6].difference, '2 期');
    },
  );

  test('marks missing configurations and unavailable XIRR explicitly', () {
    final rows = presentLoanComparison(
      first: _configuration(principal: 10000, xirr: null, periods: 12),
      second: null,
    );

    expect(rows[0].secondValue, '待配置');
    expect(rows[0].difference, '—');
    expect(rows[3].firstValue, '—');
    expect(rows[3].difference, '—');
    expect(rows[5].difference, '—');
    expect(rows[7].difference, '—');
  });
}

LoanConfiguration _configuration({
  required int principal,
  required double? xirr,
  required int periods,
}) {
  final date = DateTime(2026, 1, 15);
  final rows = [
    for (var i = 0; i < periods; i++)
      LoanCalculationPeriod(
        periodNo: i + 1,
        date: DateTime(2026, 2 + i, 15),
        principal: const Money(minorUnits: 100),
        interest: Money.zero(),
        fee: Money.zero(),
        remainingPrincipal: Money(minorUnits: 100),
      ),
  ];
  final calculation = LoanCalculation(
    periods: rows,
    stages: const [],
    totalPrincipal: Money(minorUnits: principal),
    totalInterest: const Money(minorUnits: 200),
    totalFee: Money.zero(),
    metrics: ContractMetrics(
      monthlyIrr: null,
      nominalApr: null,
      xirr: xirr,
      totalRepayment: Money(minorUnits: principal + 200),
      totalInterest: const Money(minorUnits: 200),
      totalFee: Money.zero(),
      converged: xirr != null,
      unavailableReason: xirr == null
          ? ContractMetricsUnavailableReason.noRateSolution
          : null,
    ),
  );
  return LoanConfiguration(
    principal: Money(minorUnits: principal),
    borrowingDate: date,
    terms: InstallmentTermsDraft.loan(date),
    calculation: calculation,
  );
}
