import '../../../../../core/money/rounding_mode.dart';
import '../../../valobj/installment_plan_terms.dart';
import '../calculator/interest_accrual_policy.dart';

/// 一个阶段共用的计算条款和时间安排，不持有旧计划或可变的计算进度。
class InstallmentStageContext {
  InstallmentStageContext({
    required this.stage,
    required this.dates,
    required this.start,
    required this.policy,
    required this.rounding,
  }) : accrualUnits = policy.unitsFor(
         accrual: stage.accrual,
         start: start,
         dates: dates,
         intervalMonths: stage.dates.intervalMonths,
       );

  final AmortizingStage stage;
  final List<DateTime> dates;
  final DateTime start;
  final InterestAccrualPolicy policy;
  final RoundingMode rounding;
  final List<AccrualUnit> accrualUnits;
}
