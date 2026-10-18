import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../presentation/statistics_period_presentation.dart';
import '../view_model/statistics_view_model.dart';

class StatisticsPeriodContextBar extends StatelessWidget {
  const StatisticsPeriodContextBar({
    required this.currentRange,
    required this.comparison,
    required this.onPickPeriod,
    required this.onOpenComparison,
    super.key,
  });

  final String currentRange;
  final StatisticsComparisonRange? comparison;
  final VoidCallback onPickPeriod;
  final VoidCallback onOpenComparison;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.radiusLg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _RangeBlock(
                key: const ValueKey('statistics-period-current'),
                label: '本期',
                value: currentRange,
                onTap: onPickPeriod,
                filled: true,
              ),
            ),
            const SizedBox(width: AppSpacing.space8),
            Expanded(
              child: _ComparisonBlock(
                key: const ValueKey('statistics-period-comparison'),
                label: comparison?.label ?? '对比',
                value: comparison == null
                    ? '未设置'
                    : formatStatisticsRangeLabel(
                        comparison!.from,
                        comparison!.until,
                      ),
                onTap: onOpenComparison,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeBlock extends StatelessWidget {
  const _RangeBlock({
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
    this.filled = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: filled ? colors.surfaceContainerLowest : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.space48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space10,
              vertical: AppSpacing.space6,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.appTextStyles.listSupporting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.space2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.appTextStyles.formValueEmphasis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComparisonBlock extends StatelessWidget {
  const _ComparisonBlock({
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final muted = value == '未设置';
    return Tooltip(
      message: '设置对比',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.space48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space8,
              vertical: AppSpacing.space6,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: context.appTextStyles.listSupporting.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space2),
                    Icon(
                      RemixIcons.arrow_down_s_line,
                      size: AppSpacing.space16,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.appTextStyles.formValueEmphasis.copyWith(
                    color: muted ? colors.onSurfaceVariant : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
