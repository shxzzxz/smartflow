import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../presentation/statistics_period_presentation.dart';
import '../view_model/statistics_view_model.dart';

Future<StatisticsComparisonMode?> showStatisticsComparisonSheet({
  required BuildContext context,
  required StatisticsComparisonMode selected,
  required StatisticsComparisonRange? automatic,
  required StatisticsComparisonRange? previousYear,
}) {
  return showModalBottomSheet<StatisticsComparisonMode>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space20,
          0,
          AppSpacing.space20,
          AppSpacing.space20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('设置对比', style: context.appTextStyles.sectionTitleStrong),
            const SizedBox(height: AppSpacing.space8),
            Text(
              '选择一个参照期，页面中的差异和变化会统一使用该口径。',
              style: context.appTextStyles.listSupporting,
            ),
            const SizedBox(height: AppSpacing.space16),
            _ComparisonOption(
              selected: selected == StatisticsComparisonMode.previousPeriod,
              title: '环比',
              subtitle: automatic == null
                  ? '按当前区间自动选择'
                  : formatStatisticsRangeLabel(automatic.from, automatic.until),
              onTap: () => Navigator.of(
                context,
              ).pop(StatisticsComparisonMode.previousPeriod),
            ),
            const SizedBox(height: AppSpacing.space8),
            _ComparisonOption(
              selected: selected == StatisticsComparisonMode.previousYear,
              title: '同比',
              subtitle: previousYear == null
                  ? '选择与本期相同的去年日期'
                  : formatStatisticsRangeLabel(
                      previousYear.from,
                      previousYear.until,
                    ),
              onTap: () => Navigator.of(
                context,
              ).pop(StatisticsComparisonMode.previousYear),
            ),
            const SizedBox(height: AppSpacing.space8),
            _ComparisonOption(
              selected: selected == StatisticsComparisonMode.none,
              title: '不对比',
              subtitle: '只展示本期数据，不计算参照差异',
              onTap: () =>
                  Navigator.of(context).pop(StatisticsComparisonMode.none),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ComparisonOption extends StatelessWidget {
  const _ComparisonOption({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colors.primaryContainer.withValues(alpha: .55)
          : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.appTextStyles.listTitle),
                    const SizedBox(height: AppSpacing.space4),
                    Text(subtitle, style: context.appTextStyles.listSupporting),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.space12),
              Icon(
                selected
                    ? RemixIcons.checkbox_circle_fill
                    : RemixIcons.checkbox_blank_circle_line,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
