import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/chart.dart';
import '../../../design_system/token/spacing.dart';

class CategoryProgressListItem extends StatelessWidget {
  const CategoryProgressListItem({
    required this.title,
    required this.progress,
    required this.color,
    required this.trailing,
    required this.onTap,
    this.leading,
    this.titleTrailing,
    this.titleWidth,
    this.titleTrailingGap = AppSpacing.space8,
    this.trailingGap = AppSpacing.space8,
    this.trailingWidth,
    this.footer,
    super.key,
  });

  final String title;
  final double progress;
  final Color color;
  final Widget trailing;
  final VoidCallback onTap;
  final Widget? leading;
  final Widget? titleTrailing;
  final double? titleWidth;
  final double titleTrailingGap;
  final double trailingGap;
  final double? trailingWidth;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(
      AppChartGeometry.categoryProgressHeight,
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space10),
        child: Row(
          children: [
            leading ??
                Container(
                  width: AppSpacing.space12,
                  height: AppSpacing.space12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
            SizedBox(
              width: leading == null ? AppSpacing.space10 : AppSpacing.space8,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (titleWidth case final width?
                          when titleTrailing != null)
                        SizedBox(
                          width: width,
                          child: Text(
                            title,
                            style: context.appTextStyles.listTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else
                        Expanded(
                          child: Text(
                            title,
                            style: context.appTextStyles.listTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (titleTrailing != null) ...[
                        SizedBox(width: titleTrailingGap),
                        if (titleWidth != null)
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: titleTrailing!,
                            ),
                          )
                        else
                          Flexible(child: titleTrailing!),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space6),
                  SizedBox(
                    height: AppChartGeometry.categoryProgressHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: radius,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress.clamp(0, 1),
                          heightFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: radius,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (footer != null) ...[
                    const SizedBox(height: AppSpacing.space6),
                    footer!,
                  ],
                ],
              ),
            ),
            SizedBox(width: trailingGap),
            if (trailingWidth case final width?)
              SizedBox(
                width: width,
                child: Align(alignment: Alignment.centerRight, child: trailing),
              )
            else
              trailing,
            const SizedBox(width: AppSpacing.space4),
            Icon(
              RemixIcons.arrow_right_s_line,
              color: colors.onSurfaceVariant,
              size: AppSpacing.space20,
            ),
          ],
        ),
      ),
    );
  }
}
