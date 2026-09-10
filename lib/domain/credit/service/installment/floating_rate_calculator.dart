import 'package:rational/rational.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/money/money.dart';
import '../../../../core/money/rounding_mode.dart';
import '../../valobj/credit_error_code.dart';
import '../../valobj/floating_rate.dart';
import '../../valobj/installment_enums.dart';
import '../../valobj/installment_plan_terms.dart';
import '../../valobj/interest_rate.dart';
import '../../valobj/reference_rate.dart';
import '../../valobj/repricing_principal_source.dart';
import 'interest_accrual_policy.dart';
import 'repayment_method_calculator.dart';

/// 利率按生效日期推进；每次求固定额仍使用完整剩余摊还期限。
/// 未知未来利率沿用本次已确定利率，后续重定价到来时再求解。
class FloatingRateCalculator {
  const FloatingRateCalculator();

  RepaymentMethodCalculation calculate({
    required AmortizingStage stage,
    required List<DateTime> dates,
    required DateTime start,
    required InterestAccrualPolicy policy,
    required RepaymentMethodCalculator calculator,
    required Money opening,
    required Money end,
    required RoundingMode rounding,
    RepricingPrincipalSource principalSource =
        const RepricingPrincipalSource.projection(),
  }) {
    final changes = [...stage.rateChanges]
      ..sort((a, b) => a.effectiveDate.compareTo(b.effectiveDate));
    var rate = stage.rate!;
    var previous = referenceDate(start);
    for (final change in changes) {
      if (!referenceDate(change.effectiveDate).isAfter(previous)) {
        rate = change.rate;
      }
    }
    PeriodRate normal(InterestRate value, DateTime from, DateTime to) =>
        policy.periodRate(
          rate: value,
          accrual: stage.accrual,
          span: AccrualPeriodSpan(
            days: referenceDate(to).difference(referenceDate(from)).inDays,
            months: stage.dates.intervalMonths,
          ),
        );

    _RepaymentProjection projectRemaining(
      int index,
      Money balance,
      InterestRate value, {
      PeriodRate? first,
    }) {
      var from = index == 0 ? start : dates[index - 1];
      final rates = <PeriodRate>[];
      for (var j = index; j < dates.length; j++) {
        rates.add(
          j == index && first != null ? first : normal(value, from, dates[j]),
        );
        from = dates[j];
      }
      return _RepaymentProjection(
        firstPeriodIndex: index,
        calculation: calculator.calculate(
          RepaymentMethodCalculationInput(
            openingPrincipal: balance,
            endPrincipal: end,
            rates: rates,
            rounding: rounding,
            installmentAmount: stage.installmentAmount,
          ),
        ),
      );
    }

    var projection = projectRemaining(0, opening, rate);
    var balance = opening;
    final result = <InstallmentAmountAllocation>[];
    var changed = false;
    for (var i = 0; i < dates.length; i++) {
      final until = referenceDate(dates[i]);
      var allocation = projection.allocationAt(i);
      final transition = _rateTransition(
        from: previous,
        until: until,
        openingRate: rate,
        changes: changes,
        policy: policy,
      );
      rate = transition.closingRate;
      if (transition.changed) {
        changed = true;
        final firstRate = transition.mixed
            ? PeriodRate(
                actual: transition.mixedRate,
                nominal: transition.mixedRate,
              )
            : normal(rate, previous, until);
        final recastNextPeriod =
            transition.mixed &&
            stage.method == InstallmentRepaymentMethod.equalInstallment &&
            stage.floatingRate!.paymentTiming ==
                RepricingPaymentTiming.nextPeriod;
        if (recastNextPeriod) {
          // 本期按显式来源取本金、按混合利率计息；下期才重新求固定额。
          allocation = _transitionAllocation(
            principal: principalSource.principalFor(
              date: until,
              projected: allocation.principal,
            ),
            balance: balance,
            end: end,
            rate: firstRate,
            rounding: rounding,
          );
          if (i + 1 < dates.length) {
            projection = projectRemaining(
              i + 1,
              balance - allocation.principal,
              rate,
            );
          }
        } else {
          // 当期重算，或调息发生在计息起点：直接从本期重新求解。
          projection = projectRemaining(i, balance, rate, first: firstRate);
          allocation = projection.allocationAt(i);
        }
      }
      result.add(allocation);
      balance -= allocation.principal;
      previous = until;
    }
    return RepaymentMethodCalculation(
      allocations: result,
      installmentAmount: changed
          ? null
          : projection.calculation.installmentAmount,
    );
  }

  /// 只分析 [from, until) 内的利率变化，不决定本金分摊或固定额。
  /// 同值重定价不触发按日拆息；真正跨调息的片段合计后再由调用方舍入。
  ({InterestRate closingRate, Rational mixedRate, bool changed, bool mixed})
  _rateTransition({
    required DateTime from,
    required DateTime until,
    required InterestRate openingRate,
    required List<RateChange> changes,
    required InterestAccrualPolicy policy,
  }) {
    var rate = openingRate;
    var cursor = from;
    var mixedRate = Rational.zero;
    var changed = false;
    var mixed = false;
    for (final change in changes) {
      final effective = referenceDate(change.effectiveDate);
      if (effective.isBefore(from) || !effective.isBefore(until)) continue;
      if (change.rate == rate) continue;
      mixedRate +=
          policy.dailyRate(rate) *
          Rational.fromInt(effective.difference(cursor).inDays);
      mixed = mixed || effective.isAfter(from);
      cursor = effective;
      rate = change.rate;
      changed = true;
    }
    if (changed) {
      mixedRate +=
          policy.dailyRate(rate) *
          Rational.fromInt(until.difference(cursor).inDays);
    }
    return (
      closingRate: rate,
      mixedRate: mixedRate,
      changed: changed,
      mixed: mixed,
    );
  }

  InstallmentAmountAllocation _transitionAllocation({
    required Money principal,
    required Money balance,
    required Money end,
    required PeriodRate rate,
    required RoundingMode rounding,
  }) {
    if (principal.minorUnits < 0 ||
        principal.minorUnits > balance.minorUnits - end.minorUnits) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '保留的当期本金超出剩余可摊还本金，请核对计划',
      );
    }
    return InstallmentAmountAllocation(
      principal: principal,
      interest: Money(
        minorUnits: (Rational.fromInt(balance.minorUnits) * rate.actual)
            .roundToInt(rounding),
      ),
      fee: Money.zero(),
    );
  }
}

/// 一份从指定期次开始的剩余计划预测；下标转换集中在这里。
class _RepaymentProjection {
  const _RepaymentProjection({
    required this.firstPeriodIndex,
    required this.calculation,
  });

  final int firstPeriodIndex;
  final RepaymentMethodCalculation calculation;

  InstallmentAmountAllocation allocationAt(int periodIndex) =>
      calculation.allocations[periodIndex - firstPeriodIndex];
}
