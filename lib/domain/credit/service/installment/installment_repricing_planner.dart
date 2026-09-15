import '../../entity/installment_repricing_configuration.dart';
import '../../valobj/installment_contract_terms.dart';
import '../../valobj/reference_rate.dart';

class InstallmentRepricingCandidate {
  const InstallmentRepricingCandidate(
    this.configuration,
    this.resetDate,
    this.effectiveDate,
  );
  final InstallmentRepricingConfiguration configuration;
  final DateTime resetDate, effectiveDate;
}

/// 配置归属和生成进度按重定价日判断，计息顺序按结果生效日排列。
class InstallmentRepricingPlanner {
  const InstallmentRepricingPlanner();

  List<InstallmentRepricingCandidate> due({
    required List<InstallmentRepricingConfiguration> configurations,
    required DateTime borrowingDate,
    required InstallmentContractTerms terms,
    required DateTime now,
  }) {
    final candidates = <InstallmentRepricingCandidate>[];
    for (final stageId in configurations.map((c) => c.stageId).toSet()) {
      final range = terms.repaymentRange(stageId, borrowingDate);
      final ordered = configurations.where((c) => c.stageId == stageId).toList()
        ..sort(
          (a, b) => referenceDate(
            a.effectiveFrom,
          ).compareTo(referenceDate(b.effectiveFrom)),
        );
      for (var c = 0; c < ordered.length; c++) {
        final configuration = ordered[c];
        if (configuration.generationCompleted) continue;
        configuration.validate();
        final next = c + 1 < ordered.length
            ? ordered[c + 1].effectiveFrom
            : null;
        final rule = configuration.rule;
        for (
          var i = _nextCycle(configuration);
          !rule.resetDate(i).isAfter(referenceDate(now)) &&
              rule.effectiveDate(i).isBefore(range.end) &&
              configuration.owns(rule.resetDate(i), next);
          i++
        ) {
          final reset = rule.resetDate(i);
          final effective = rule.effectiveDate(i);
          // 阶段开始前的结果可决定初始计息利率，只按阶段末日停止生成。
          candidates.add(
            InstallmentRepricingCandidate(configuration, reset, effective),
          );
        }
      }
    }
    candidates.sort((a, b) => a.effectiveDate.compareTo(b.effectiveDate));
    return candidates;
  }

  /// 完成由下一周期是否仍有归属决定，与今日是否已到该周期无关。
  List<InstallmentRepricingConfiguration> completed({
    required List<InstallmentRepricingConfiguration> configurations,
    required DateTime borrowingDate,
    required InstallmentContractTerms terms,
  }) {
    final completed = <InstallmentRepricingConfiguration>[];
    for (final stageId in configurations.map((c) => c.stageId).toSet()) {
      final end = terms.repaymentRange(stageId, borrowingDate).end;
      final ordered = configurations.where((c) => c.stageId == stageId).toList()
        ..sort(
          (a, b) => referenceDate(
            a.effectiveFrom,
          ).compareTo(referenceDate(b.effectiveFrom)),
        );
      for (var i = 0; i < ordered.length; i++) {
        final configuration = ordered[i];
        if (configuration.generationCompleted) continue;
        configuration.validate();
        final cycle = _nextCycle(configuration);
        final next = i + 1 < ordered.length
            ? ordered[i + 1].effectiveFrom
            : null;
        if (!configuration.rule.effectiveDate(cycle).isBefore(end) ||
            !configuration.owns(configuration.rule.resetDate(cycle), next)) {
          completed.add(configuration.withGenerationCompleted(true));
        }
      }
    }
    return completed;
  }

  int _nextCycle(InstallmentRepricingConfiguration configuration) {
    var from = referenceDate(configuration.effectiveFrom);
    final last = configuration.lastGeneratedDate;
    if (last != null) {
      final afterLast = referenceDate(last).add(const Duration(days: 1));
      if (afterLast.isAfter(from)) from = afterLast;
    }
    return configuration.rule.resetCycleOnOrAfter(from);
  }
}
