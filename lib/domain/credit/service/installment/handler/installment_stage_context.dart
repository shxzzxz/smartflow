import '../../../../../core/money/rounding_mode.dart';
import '../../../valobj/installment_plan_terms.dart';
import '../../../valobj/reference_rate.dart';
import '../calculator/interest_accrual_policy.dart';

/// 一个阶段共用的计算条款和时间安排，不持有旧计划或可变的计算进度。
class InstallmentStageContext {
  InstallmentStageContext({
    required this.stage,
    required this.dates,
    required this.start,
    required this.policy,
    required this.rounding,
  }) : accrualUnits = List.unmodifiable(
         policy
             .unitsFor(
               accrual: stage.accrual,
               start: start,
               dates: dates,
               intervalMonths: stage.dates.intervalMonths,
             )
             .map(
               (unit) => AccrualUnit(
                 start: unit.start.add(const Duration(days: 1)),
                 end: unit.end.add(const Duration(days: 1)),
                 startMonth: unit.startMonth,
                 endMonth: unit.endMonth,
               ),
             ),
       );

  final AmortizingStage stage;
  final List<DateTime> dates;
  final DateTime start;
  final InterestAccrualPolicy policy;
  final RoundingMode rounding;
  final List<AccrualUnit> accrualUnits;

  /// 业务周期 (上期还款日, 本期还款日] 对应的起始包含、结束不包含日期。
  /// 首期的左边界为合同借款日或阶段约定的起息边界。
  ({DateTime start, DateTime end}) periodRange(int periodIndex) => (
    start: referenceDate(
      periodIndex == 0 ? start : dates[periodIndex - 1],
    ).add(const Duration(days: 1)),
    end: referenceDate(dates[periodIndex]).add(const Duration(days: 1)),
  );
}
