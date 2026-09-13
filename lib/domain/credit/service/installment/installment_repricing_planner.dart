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

/// 配置归属以结果生效日判断；永久日历锚点避免月末日期漂移。
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
        configuration.validate();
        final next = c + 1 < ordered.length
            ? ordered[c + 1].effectiveFrom
            : null;
        final rule = configuration.rule;
        for (
          var i = 0;
          !rule.resetDate(i).isAfter(referenceDate(now)) &&
              rule.effectiveDate(i).isBefore(range.end);
          i++
        ) {
          final effective = rule.effectiveDate(i);
          if (effective.isBefore(range.start) ||
              !configuration.owns(effective, next) ||
              (configuration.lastGeneratedDate != null &&
                  !effective.isAfter(
                    referenceDate(configuration.lastGeneratedDate!),
                  ))) {
            continue;
          }
          candidates.add(
            InstallmentRepricingCandidate(
              configuration,
              rule.resetDate(i),
              effective,
            ),
          );
        }
      }
    }
    candidates.sort((a, b) => a.effectiveDate.compareTo(b.effectiveDate));
    return candidates;
  }
}
