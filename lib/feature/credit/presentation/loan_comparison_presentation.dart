import '../view_model/loan_configuration_view_model.dart';
import 'loan_calculator_presentation.dart';

class LoanComparisonRowPresentation {
  const LoanComparisonRowPresentation({
    required this.label,
    required this.firstValue,
    required this.secondValue,
    required this.difference,
  });

  final String label;
  final String firstValue;
  final String secondValue;
  final String difference;
}

List<LoanComparisonRowPresentation> presentLoanComparison({
  required LoanConfiguration? first,
  required LoanConfiguration? second,
}) {
  String value(
    LoanConfiguration? configuration,
    String Function(LoanConfiguration) read,
  ) {
    return configuration == null ? '待配置' : read(configuration);
  }

  String difference(
    String Function(LoanConfiguration, LoanConfiguration)? read,
  ) {
    if (first == null || second == null || read == null) return '—';
    return read(first, second);
  }

  return [
    LoanComparisonRowPresentation(
      label: '本金',
      firstValue: value(first, (c) => c.principal.format()),
      secondValue: value(second, (c) => c.principal.format()),
      difference: difference((a, b) => (a.principal - b.principal).format()),
    ),
    LoanComparisonRowPresentation(
      label: '总还款',
      firstValue: value(first, (c) => c.calculation.totalRepayment.format()),
      secondValue: value(second, (c) => c.calculation.totalRepayment.format()),
      difference: difference(
        (a, b) => (a.calculation.totalRepayment - b.calculation.totalRepayment)
            .format(),
      ),
    ),
    LoanComparisonRowPresentation(
      label: '总利息',
      firstValue: value(first, (c) => c.calculation.totalInterest.format()),
      secondValue: value(second, (c) => c.calculation.totalInterest.format()),
      difference: difference(
        (a, b) => (a.calculation.totalInterest - b.calculation.totalInterest)
            .format(),
      ),
    ),
    LoanComparisonRowPresentation(
      label: '总手续费',
      firstValue: value(first, (c) => c.calculation.totalFee.format()),
      secondValue: value(second, (c) => c.calculation.totalFee.format()),
      difference: difference(
        (a, b) => (a.calculation.totalFee - b.calculation.totalFee).format(),
      ),
    ),
    LoanComparisonRowPresentation(
      label: '实际年化 XIRR',
      firstValue: value(
        first,
        (c) => formatRatePercent(c.calculation.metrics.xirr),
      ),
      secondValue: value(
        second,
        (c) => formatRatePercent(c.calculation.metrics.xirr),
      ),
      difference: difference((a, b) {
        final firstRate = a.calculation.metrics.xirr;
        final secondRate = b.calculation.metrics.xirr;
        return firstRate == null || secondRate == null
            ? '—'
            : formatRatePercent(firstRate - secondRate);
      }),
    ),
  ];
}
