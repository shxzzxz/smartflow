import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_operation.dart';
import 'package:smartflow/feature/credit/presentation/loan_change_presentation.dart';

void main() {
  test('compares XIRR after the operation against the original plan', () {
    final simulation = _simulation(beforeXirr: 0.08, afterXirr: 0.09);

    final rows = presentLoanChangeComparison(simulation);

    expect(rows.map((row) => row.label).toList(), [
      '总还款',
      '总利息',
      '总手续费',
      '息费合计',
      '实际年化 XIRR',
    ]);
    expect(rows.last.firstValue, '8.00%');
    expect(rows.last.secondValue, '9.00%');
    expect(rows.last.difference, '+1.00%');
  });

  test('marks an unavailable changed XIRR explicitly', () {
    final simulation = _simulation(beforeXirr: 0.08, afterXirr: null);

    final xirr = presentLoanChangeComparison(simulation).last;

    expect(xirr.firstValue, '8.00%');
    expect(xirr.secondValue, '—');
    expect(xirr.difference, '—');
  });
}

LoanChangeSimulation _simulation({
  required double? beforeXirr,
  required double? afterXirr,
}) {
  final calculation = LoanCalculation(
    periods: const [],
    stages: const [],
    totalPrincipal: const Money(minorUnits: 10000),
    totalInterest: const Money(minorUnits: 100),
    totalFee: const Money(minorUnits: 20),
    metrics: _metrics(beforeXirr),
  );
  return LoanChangeSimulation(
    original: calculation,
    operations: const InstallmentPlanOperations(),
    periods: const [],
    stages: const [],
    totalInterest: const Money(minorUnits: 90),
    totalFee: const Money(minorUnits: 20),
    changedMetrics: _metrics(afterXirr),
  );
}

ContractMetrics _metrics(double? xirr) {
  return ContractMetrics(
    monthlyIrr: null,
    nominalApr: null,
    xirr: xirr,
    totalRepayment: const Money(minorUnits: 10120),
    totalInterest: const Money(minorUnits: 100),
    totalFee: const Money(minorUnits: 20),
    converged: xirr != null,
    unavailableReason: xirr == null
        ? ContractMetricsUnavailableReason.noRateSolution
        : null,
  );
}
