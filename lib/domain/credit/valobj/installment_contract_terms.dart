import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/money/rounding_mode.dart';
import 'credit_error_code.dart';
import 'day_count_convention.dart';
import 'equal_installment_amount.dart';
import 'installment_enums.dart';
import 'installment_plan_terms.dart';
import 'interest_rate.dart';
import 'repayment_dates_strategy.dart';
import 'tail_difference_policy.dart';
import 'floating_rate.dart';

/// 阶段身份与条款分开：规则修改后仍可识别原有计划所属的阶段。
class InstallmentContractStage {
  const InstallmentContractStage({required this.id, required this.terms});
  final String id;
  final InstallmentStage terms;
}

class InstallmentContractTerms {
  InstallmentContractTerms({
    required List<InstallmentContractStage> stages,
    this.dayCount = DayCountConvention.thirty360,
    this.rounding = RoundingMode.halfUp,
    this.tailDifference = TailDifferencePolicy.lastPeriod,
  }) : stages = List.unmodifiable(stages);

  final List<InstallmentContractStage> stages;
  final DayCountConvention dayCount;
  final RoundingMode rounding;
  final TailDifferencePolicy tailDifference;

  bool hasSameLayout(InstallmentContractTerms other) {
    if (stages.length != other.stages.length) return false;
    for (var i = 0; i < stages.length; i++) {
      final left = stages[i], right = other.stages[i];
      if (left.id != right.id ||
          left.terms.runtimeType != right.terms.runtimeType) {
        return false;
      }
      if (left.terms is AmortizingStage &&
          (left.terms as AmortizingStage).dates.getDates().length !=
              (right.terms as AmortizingStage).dates.getDates().length) {
        return false;
      }
    }
    return true;
  }

  /// 编辑只能保留已有利率事实；追加事实必须通过应用重定价。
  void validateReplacementOf(InstallmentContractTerms previous) {
    validate();
    for (final oldStage in previous.stages) {
      if (oldStage.terms is! AmortizingStage) continue;
      final old = oldStage.terms as AmortizingStage;
      final replacement = stages
          .where((s) => s.id == oldStage.id)
          .firstOrNull
          ?.terms;
      if (old.rateChanges.isNotEmpty &&
          (replacement is! AmortizingStage ||
              replacement.rate != old.rate ||
              replacement.floatingRate != old.floatingRate)) {
        _invalid('已有重定价结果的利率规则不能改写');
      }
    }
    for (final stage in stages) {
      if (stage.terms is! AmortizingStage) continue;
      final next = stage.terms as AmortizingStage;
      final old = previous.stages
          .where((s) => s.id == stage.id)
          .firstOrNull
          ?.terms;
      final changes = old is AmortizingStage ? old.rateChanges : <RateChange>[];
      if (changes.length != next.rateChanges.length ||
          List.generate(
            changes.length,
            (i) => !_sameRateChange(changes[i], next.rateChanges[i]),
          ).any((v) => v)) {
        _invalid('已有重定价结果不能通过合同编辑改写，请重新打开合同');
      }
    }
  }

  InstallmentContractTerms withRepricing(String stageId, RateChange change) {
    final stage = stages.where((s) => s.id == stageId).firstOrNull?.terms;
    if (stage is! AmortizingStage || stage.floatingRate == null) {
      _invalid('重定价所属阶段已改变，请核对合同');
    }
    final next = AmortizingStage(
      dates: stage.dates,
      method: stage.method,
      accrualStartDate: stage.accrualStartDate,
      rate: stage.rate,
      accrual: stage.accrual,
      floatingRate: stage.floatingRate,
      rateChanges: List.unmodifiable([...stage.rateChanges, change]),
      endPrincipal: stage.endPrincipal,
      fee: stage.fee,
      installmentAmount: stage.installmentAmount,
    );
    next.validateFloatingRate();
    return InstallmentContractTerms(
      dayCount: dayCount,
      rounding: rounding,
      tailDifference: tailDifference,
      stages: [
        for (final s in stages)
          s.id == stageId ? InstallmentContractStage(id: s.id, terms: next) : s,
      ],
    );
  }

  static bool _sameRateChange(RateChange a, RateChange b) =>
      a.resetDate == b.resetDate &&
      a.effectiveDate == b.effectiveDate &&
      a.spreadBp == b.spreadBp &&
      a.referenceRate.type == b.referenceRate.type &&
      a.referenceRate.date == b.referenceRate.date &&
      a.referenceRate.ratePpm == b.referenceRate.ratePpm;

  InstallmentPlanTerms planTerms(Money principal, DateTime borrowingDate) =>
      InstallmentPlanTerms(
        principal: principal,
        borrowingDate: borrowingDate,
        stages: [for (final stage in stages) stage.terms],
        dayCount: dayCount,
        rounding: rounding,
        tailDifference: tailDifference,
      );

  void validate() {
    if (!DayCountConvention.values.contains(dayCount)) {
      _invalid('不支持的利率换算标准天数');
    }
    final ids = <String>{};
    DateTime? previousDate;
    for (final stage in stages) {
      if (stage.terms case final AmortizingStage repayment) {
        repayment.validateFloatingRate();
      }
      if (stage.id.isEmpty || !ids.add(stage.id)) _invalid('阶段标识必须唯一');
      if (stage.terms case DefermentStage(:final until)) {
        if (previousDate != null && !until.isAfter(previousDate)) {
          _invalid('阶段日期必须递增');
        }
        previousDate = until;
      }
      if (stage.terms case AmortizingStage(
        :final dates,
        :final method,
        :final fee,
        :final rate,
        :final endPrincipal,
        :final installmentAmount,
      )) {
        if (dates is! IntervalRepaymentDates) {
          _invalid('合同条款使用首期日期、期数与间隔；单期日期调整请编辑还款计划');
        }
        if (dates.count <= 0 || dates.intervalMonths <= 0) {
          _invalid('期数与间隔月数必须为正整数');
        }
        if (fee.minorUnits < 0 ||
            (rate?.ppm ?? 0) < 0 ||
            (endPrincipal?.minorUnits ?? 0) < 0) {
          _invalid('利率、手续费与期末本金不得为负');
        }
        final values = dates.getDates();
        for (final date in values) {
          if (previousDate != null && !date.isAfter(previousDate)) {
            _invalid('阶段日期必须递增');
          }
          previousDate = date;
        }
        if (values.isEmpty) _invalid('还款阶段至少需要一期');
        if (method == InstallmentRepaymentMethod.flatFee &&
            (values.length != 1 || rate != null)) {
          _invalid('一次性手续费阶段只允许一次还款且不另计利息');
        }
        if (installmentAmount case FixedInstallmentAmount(:final amount)) {
          if (method != InstallmentRepaymentMethod.equalInstallment ||
              amount.minorUnits <= 0) {
            _invalid('指定固定额必须为正且仅用于等额本息');
          }
        }
      }
    }
    if (!stages.any((s) => s.terms is AmortizingStage)) {
      _invalid('至少需要一个还款阶段');
    }
  }

  List<AmortizingStage> get repayments =>
      stages.map((s) => s.terms).whereType<AmortizingStage>().toList();
  int get totalPeriods =>
      repayments.fold(0, (n, s) => n + s.dates.getDates().length);
  DateTime get firstDate => repayments.first.dates.getDates().first;
  DateTime get lastDate => repayments.last.dates.getDates().last;
  int get totalFeeMinor => repayments.fold(0, (n, s) => n + s.fee.minorUnits);

  factory InstallmentContractTerms.singleStage({
    String id = 'stage-1',
    required int totalPeriods,
    required DateTime firstDate,
    DateTime? lastDate,
    required InstallmentRepaymentMethod method,
    required InterestAccrualMethod accrual,
    InterestRatePeriod? ratePeriod,
    int? ratePpm,
    int feeMinor = 0,
    int? fixedAmountMinor,
  }) {
    if ((ratePeriod == null) != (ratePpm == null)) _invalid('利率单位与数值必须同时设置');
    return InstallmentContractTerms(
      stages: [
        InstallmentContractStage(
          id: id,
          terms: AmortizingStage(
            dates: IntervalRepaymentDates(
              firstDate: firstDate,
              lastDate: lastDate,
              count: totalPeriods,
            ),
            method: method,
            accrual: accrual,
            rate: InterestRate.maybe(ratePeriod, ratePpm),
            fee: Money(minorUnits: feeMinor),
            installmentAmount: fixedAmountMinor != null
                ? EqualInstallmentAmount.fixed(
                    Money(minorUnits: fixedAmountMinor),
                  )
                : const EqualInstallmentAmount.actualRate(),
          ),
        ),
      ],
    );
  }

  static Never _invalid(String message) => throw BusinessException(
    CreditErrorCode.contractInvalidCommand,
    message: message,
  );
}
