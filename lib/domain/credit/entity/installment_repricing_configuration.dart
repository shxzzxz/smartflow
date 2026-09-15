import '../../../core/error/app_exception.dart';
import '../valobj/credit_error_code.dart';
import '../valobj/floating_rate.dart';
import '../valobj/reference_rate.dart';

class InstallmentRepricingConfiguration {
  const InstallmentRepricingConfiguration({
    required this.id,
    required this.contractId,
    required this.stageId,
    required this.effectiveFrom,
    required this.rule,
    this.lastGeneratedDate,
    this.generationCompleted = false,
  });

  final String id, contractId, stageId;
  final DateTime effectiveFrom;
  final FloatingRateRule rule;

  /// 已成功处理的最后一个重定价日；删除结果不会回退此进度。
  final DateTime? lastGeneratedDate;

  /// 当前配置区间及阶段末日内，已无尚待处理的周期。
  final bool generationCompleted;

  InstallmentRepricingConfiguration withGenerationCompleted(bool completed) =>
      InstallmentRepricingConfiguration(
        id: id,
        contractId: contractId,
        stageId: stageId,
        effectiveFrom: effectiveFrom,
        rule: rule,
        lastGeneratedDate: lastGeneratedDate,
        generationCompleted: completed,
      );

  void validate() {
    rule.validate();
    if (id.isEmpty ||
        contractId.isEmpty ||
        stageId.isEmpty ||
        (lastGeneratedDate != null &&
            referenceDate(
              lastGeneratedDate!,
            ).isBefore(referenceDate(effectiveFrom)))) {
      throw BusinessException(CreditErrorCode.contractInvalidCommand);
    }
  }

  bool owns(DateTime resetDate, DateTime? nextEffectiveFrom) =>
      !referenceDate(resetDate).isBefore(referenceDate(effectiveFrom)) &&
      (nextEffectiveFrom == null ||
          referenceDate(resetDate).isBefore(referenceDate(nextEffectiveFrom)));
}
