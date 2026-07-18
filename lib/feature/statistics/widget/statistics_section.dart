import 'package:flutter/material.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/chart.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';

enum StatisticsSectionEmphasis { primary, secondary }

class StatisticsSectionCard extends StatelessWidget {
  const StatisticsSectionCard({
    required this.title,
    required this.child,
    super.key,
    this.subtitle,
    this.onTitleTap,
    this.titleActionIcon,
    this.titleTooltip,
    this.trailing,
    this.emphasis = StatisticsSectionEmphasis.secondary,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onTitleTap;
  final IconData? titleActionIcon;
  final String? titleTooltip;
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitle(context, colors),
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

  Widget _buildTitle(BuildContext context, ColorScheme colors) {
    final text = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style:
          emphasis == StatisticsSectionEmphasis.primary
              ? context.appTextStyles.sectionTitleStrong
              : context.appTextStyles.subsectionTitleStrong,
    );
    if (onTitleTap == null) return text;
    return Tooltip(
      message: titleTooltip ?? title,
      child: Semantics(
        button: true,
        label: titleTooltip ?? title,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          child: InkWell(
            key: const ValueKey('statistics-section-title-action'),
            onTap: onTitleTap,
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSpacing.space48),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: text),
                  if (titleActionIcon != null) ...[
                    const SizedBox(width: AppSpacing.space4),
                    Icon(
                      titleActionIcon,
                      size: AppSpacing.space16,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ),
          ),
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
