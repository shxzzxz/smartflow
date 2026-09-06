import '../../../application/credit/credit_query_api.dart';
import '../../../core/money/money.dart';
import '../../../core/money/rounding_mode.dart';

/// 等额本息固定额算法在页面上的选择项。
enum EqualInstallmentAmountMode { nominalRate, actualRate, fixed }

EqualInstallmentAmount equalInstallmentAmountFor(
  EqualInstallmentAmountMode mode, {
  Money? fixedAmount,
}) {
  return switch (mode) {
    EqualInstallmentAmountMode.nominalRate =>
      const EqualInstallmentAmount.nominalRate(),
    EqualInstallmentAmountMode.actualRate =>
      const EqualInstallmentAmount.actualRate(),
    EqualInstallmentAmountMode.fixed => EqualInstallmentAmount.fixed(
      fixedAmount ?? Money.zero(),
    ),
  };
}

String equalInstallmentAmountModeLabel(EqualInstallmentAmountMode mode) {
  return switch (mode) {
    EqualInstallmentAmountMode.nominalRate => '固定名义期利率',
    EqualInstallmentAmountMode.actualRate => '动态实际期利率',
    EqualInstallmentAmountMode.fixed => '指定固定额',
  };
}

String loanRepaymentMethodLabel(InstallmentRepaymentMethod method) {
  return switch (method) {
    InstallmentRepaymentMethod.equalInstallment => '等额本息',
    InstallmentRepaymentMethod.equalPrincipal => '等额本金',
    InstallmentRepaymentMethod.interestFirst => '先息后本',
    InstallmentRepaymentMethod.flatFee => '一次性手续费',
    InstallmentRepaymentMethod.custom => '自定义',
  };
}

String interestAccrualMethodLabel(InterestAccrualMethod method) {
  return switch (method) {
    InterestAccrualMethod.daily => '按日计息',
    InterestAccrualMethod.monthly => '按月计息',
    InterestAccrualMethod.annual => '按年计息',
  };
}

String dayCountConventionLabel(DayCountConvention convention) {
  return '月 ${convention.daysPerMonth} 天 / 年 ${convention.daysPerYear} 天';
}

String roundingModeLabel(RoundingMode mode) {
  return switch (mode) {
    RoundingMode.halfUp => '四舍五入',
    RoundingMode.halfEven => '银行家舍入',
    RoundingMode.down => '舍去',
    RoundingMode.up => '进一',
  };
}

String contractMetricsUnavailableLabel(
  ContractMetricsUnavailableReason reason,
) {
  return switch (reason) {
    ContractMetricsUnavailableReason.principalNotConserved => '计划本金与借款本金不一致',
    ContractMetricsUnavailableReason.insufficientCashflows => '现金流不足以求解利率',
    ContractMetricsUnavailableReason.noRateSolution => '现金流没有利率解',
  };
}

/// 小数利率（0.0123）格式化为百分数文本（1.23%）。
String formatRatePercent(double? value, {int fractionDigits = 2}) {
  if (value == null) return '—';
  return '${(value * 100).toStringAsFixed(fractionDigits)}%';
}

/// 带符号的金额差额：正数加 +，零显示 0.00。
String formatSignedMoney(Money value) {
  if (value.minorUnits > 0) return '+${value.format()}';
  return value.format();
}

/// 计算结果中某一期的本息费摘要。
String loanPeriodBreakdownText(LoanCalculationPeriod period) {
  final buffer = StringBuffer('本金 ${period.principal.format()}');
  if (period.interest.minorUnits != 0) {
    buffer.write('  利息 ${period.interest.format()}');
  }
  if (period.fee.minorUnits != 0) {
    buffer.write('  手续费 ${period.fee.format()}');
  }
  return buffer.toString();
}
