import 'package:flutter/material.dart';

import '../../../../design_system/token/radius.dart';
import '../../../../design_system/token/spacing.dart';
import 'insurance_metric_strip.dart';

class InsurancePolicyFactsPanel extends StatelessWidget {
  const InsurancePolicyFactsPanel({
    required this.coverageAmountLabel,
    required this.coverageTermLabel,
    required this.premiumLabel,
    super.key,
  });

  final String coverageAmountLabel;
  final String coverageTermLabel;
  final String premiumLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.radiusXl),
      ),
      child: InsuranceMetricStrip(
        metrics: [
          InsuranceMetric(label: '保额', value: coverageAmountLabel),
          InsuranceMetric(label: '保障期限', value: coverageTermLabel),
          InsuranceMetric(label: '缴费方式', value: premiumLabel),
        ],
      ),
    );
  }
}
