import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/list.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';

/// A compact summary of an import analysis result.
///
/// The import process page intentionally keeps the large mapping and preview
/// lists behind a dedicated details page.  This card is the shared summary
/// surface used by both locations so the two views keep the same hierarchy.
class ImportAnalysisCard extends StatelessWidget {
  const ImportAnalysisCard({
    required this.title,
    required this.metrics,
    required this.description,
    this.icon = RemixIcons.file_search_line,
    this.onViewAll,
    this.showViewAll = true,
    super.key,
  });

  final String title;
  final IconData icon;
  final List<ImportAnalysisMetric> metrics;
  final String description;
  final VoidCallback? onViewAll;
  final bool showViewAll;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      border: true,
      borderRadius: AppRadius.radiusXl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space16,
          AppSpacing.space14,
          AppSpacing.space16,
          AppSpacing.space14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: AppSpacing.space32,
                  height: AppSpacing.space32,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                  ),
                  child: Icon(
                    icon,
                    size: AppSpacing.space18,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.space10),
                Expanded(
                  child: Text(title, style: context.appTextStyles.listTitle),
                ),
                if (showViewAll)
                  TextButton(onPressed: onViewAll, child: const Text('查看全部')),
              ],
            ),
            const SizedBox(height: AppSpacing.space16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < metrics.length; index++) ...[
                  if (index > 0) const SizedBox(width: AppSpacing.space8),
                  Expanded(child: _Metric(metric: metrics[index])),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.space14),
            Divider(
              height: AppListTokens.dividerThickness,
              thickness: AppListTokens.dividerThickness,
              color: colors.outlineVariant.withValues(
                alpha: AppListTokens.dividerOpacity,
              ),
            ),
            const SizedBox(height: AppSpacing.space10),
            Text(description, style: context.appTextStyles.metricSupporting),
          ],
        ),
      ),
    );
  }
}

class ImportAnalysisMetric {
  const ImportAnalysisMetric({required this.label, required this.value});

  final String label;
  final int value;
}

class _Metric extends StatelessWidget {
  const _Metric({required this.metric});

  final ImportAnalysisMetric metric;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${metric.value}', style: context.appTextStyles.metricValue),
        const SizedBox(height: AppSpacing.space4),
        Text(
          metric.label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.appTextStyles.metricLabel,
        ),
      ],
    );
  }
}
