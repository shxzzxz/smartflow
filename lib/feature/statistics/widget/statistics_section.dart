import 'package:flutter/material.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/chart.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';

enum StatisticsSectionEmphasis { primary, secondary }

class StatisticsSectionCard extends StatelessWidget {
  const StatisticsSectionCard({
    required this.title,
    required this.child,
    super.key,
    this.subtitle,
    this.trailing,
    this.emphasis = StatisticsSectionEmphasis.secondary,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final StatisticsSectionEmphasis emphasis;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      border: emphasis == StatisticsSectionEmphasis.primary,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style:
                            emphasis == StatisticsSectionEmphasis.primary
                                ? context.appTextStyles.sectionTitleStrong
                                : context.appTextStyles.subsectionTitleStrong,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.space4),
                        Text(
                          subtitle!,
                          style: context.appTextStyles.listSupporting.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.space8),
                  trailing!,
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.space16),
            child,
          ],
        ),
      ),
    );
  }
}

class StatisticsEmptyState extends StatelessWidget {
  const StatisticsEmptyState({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: AppChartGeometry.emptyStateHeight,
      child: Center(
        child: Text(
          message,
          style: context.appTextStyles.listSupporting.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
