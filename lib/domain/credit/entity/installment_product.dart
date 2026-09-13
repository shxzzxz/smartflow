import '../../../core/error/app_exception.dart';
import '../../../core/money/rounding_mode.dart';
import '../valobj/credit_error_code.dart';
import '../valobj/day_count_convention.dart';
import '../valobj/installment_stage_rule.dart';
import '../valobj/installment_enums.dart';
import '../valobj/tail_difference_policy.dart';

class InstallmentProduct {
  InstallmentProduct({
    required this.id,
    required this.name,
    required List<InstallmentStageRule> stages,
    required this.createdAt,
    this.archived = false,
    this.dayCount = DayCountConvention.thirty360,
    this.rounding = RoundingMode.halfUp,
    this.tailDifference = TailDifferencePolicy.lastPeriod,
  }) : stages = List.unmodifiable(stages);

  final String id;
  final String name;
  final bool archived;
  final DateTime createdAt;
  final List<InstallmentStageRule> stages;
  final DayCountConvention dayCount;
  final RoundingMode rounding;
  final TailDifferencePolicy tailDifference;

  void validate() {
    if (stages.any(
          (stage) => stage.method == InstallmentRepaymentMethod.custom,
        ) &&
        stages.any(
          (stage) => stage.method != InstallmentRepaymentMethod.custom,
        )) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '自定义阶段不能与其他阶段混用',
      );
    }
    if (!DayCountConvention.values.contains(dayCount) ||
        name.trim().isEmpty ||
        stages.isEmpty ||
        !stages.any((s) => s.kind == InstallmentStageKind.repayment) ||
        stages.map((s) => s.id).toSet().length != stages.length) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '请输入产品名称并配置至少一个还款阶段',
      );
    }
    for (final stage in stages) {
      stage.validate();
    }
  }
}
