import 'package:flutter/material.dart';

import '../../../../design_system/theme/app_text_styles.dart';
import '../../../../design_system/token/component.dart';
import '../../../../design_system/token/spacing.dart';
import '../../../../design_system/token/typography.dart';

class InsuranceMetric {
  const InsuranceMetric({
    required this.label,
    required this.value,
    this.unit,
    this.icon,
  });

  final String label;
  final String value;
  final String? unit;
  final IconData? icon;
}

class InsuranceMetricStrip extends StatelessWidget {
  const InsuranceMetricStrip({
    required this.metrics,
    super.key,
    this.showDividers = true,
  }) : assert(metrics.length > 0);

  final List<InsuranceMetric> metrics;
  final bool showDividers;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < metrics.length; index++) ...[
          Expanded(child: _MetricItem(metric: metrics[index])),
          if (index < metrics.length - 1 && showDividers)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space8,
              ),
              child: Container(
                width: AppComponentTokens.outlineWidth,
                height: AppSpacing.space48,
                color: colors.outlineVariant.withValues(
                  alpha: AppComponentTokens.mutedOutlineOpacity,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({required this.metric});

  final InsuranceMetric metric;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final styles = context.appTextStyles;
    final valueStyle = styles.amountPrimary.copyWith(
      color: colors.onSurface,
      height: AppTypography.lineHeightTight,
    );
    final unitStyle = styles.metricSupporting.copyWith(
      fontSize: AppTypography.fontSizeXs,
      fontWeight: AppTypography.emphasisWeight,
      height: AppTypography.lineHeightTight,
    );
    return Semantics(
      label: '${metric.label}，${metric.value}${metric.unit ?? ''}',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (metric.icon case final icon?) ...[
              Icon(icon, size: AppSpacing.space20, color: colors.primary),
              const SizedBox(height: AppSpacing.space6),
            ],
            Text(
              metric.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: styles.metricSupporting,
            ),
            const SizedBox(height: AppSpacing.space4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(metric.value, maxLines: 1, style: valueStyle),
                  if (metric.unit case final unit?) ...[
                    const SizedBox(width: AppSpacing.space4),
                    Text(unit, maxLines: 1, style: unitStyle),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
