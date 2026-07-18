import 'package:flutter/material.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';
import 'package:smartflow/widget/business/finance/finance_tone_color.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';

class CashflowSummaryCard extends StatelessWidget {
  const CashflowSummaryCard({
    required this.summary,
    this.showCaptions = true,
    super.key,
  });

  final CashflowSummaryPresentation summary;
  final bool showCaptions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    final metrics = summary.metrics;

    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space16,
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              for (var i = 0; i < metrics.length; i++) ...[
                if (i > 0) _SummaryDivider(color: colors.outlineVariant),
                Expanded(
                  child: _SummaryMetric(
                    metric: metrics[i],
                    showCaption: showCaptions,
                    amountColor: financeToneColor(
                      colors,
                      financeColors,
                      metrics[i].tone,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space12,
        vertical: AppSpacing.space4,
      ),
      color: color.withValues(alpha: 0.6),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.metric,
    required this.showCaption,
    required this.amountColor,
  });

  final CashflowSummaryMetricPresentation metric;
  final bool showCaption;
  final Color amountColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          metric.label,
          style: textStyles.metricLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.space6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            metric.amountText,
            style: textStyles.metricValue.copyWith(color: amountColor),
            maxLines: 1,
          ),
        ),
        if (showCaption) ...[
          const SizedBox(height: AppSpacing.space6),
          Text(
            metric.caption,
            style: textStyles.metricSupporting.copyWith(
              color: colors.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
