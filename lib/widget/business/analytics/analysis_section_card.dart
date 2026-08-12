import 'package:flutter/material.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/token/typography.dart';
import '../../../design_system/widget/app_surface.dart';

enum AnalysisSectionEmphasis { primary, secondary }

class AnalysisSectionCard extends StatelessWidget {
  const AnalysisSectionCard({
    required this.title,
    required this.child,
    super.key,
    this.subtitle,
    this.onTitleTap,
    this.titleActionIcon,
    this.titleActionIconSize = AppSpacing.space16,
    this.titleTooltip,
    this.trailing,
    this.headerPadding = const EdgeInsets.fromLTRB(
      AppSpacing.space16,
      AppSpacing.space16,
      AppSpacing.space16,
      0,
    ),
    this.contentPadding = const EdgeInsets.fromLTRB(
      AppSpacing.space16,
      AppSpacing.space16,
      AppSpacing.space16,
      AppSpacing.space16,
    ),
    this.emphasis = AnalysisSectionEmphasis.secondary,
    this.border = false,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onTitleTap;
  final IconData? titleActionIcon;
  final double titleActionIconSize;
  final String? titleTooltip;
  final Widget? trailing;
  final EdgeInsetsGeometry headerPadding;
  final EdgeInsetsGeometry contentPadding;
  final Widget child;
  final AnalysisSectionEmphasis emphasis;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final titleContent = Column(
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
    );
    final referenceTextSize = AppTypography.fontSizeMd;
    final scaledReferenceTextSize = MediaQuery.textScalerOf(
      context,
    ).scale(referenceTextSize);
    final stackHeader =
        scaledReferenceTextSize / referenceTextSize >
        AppComponentTokens.adaptiveLayoutTextScaleThreshold;

    return AppSurface(
      border: border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: headerPadding,
            child:
                stackHeader
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleContent,
                        if (trailing != null) ...[
                          const SizedBox(height: AppSpacing.space8),
                          trailing!,
                        ],
                      ],
                    )
                    : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: titleContent),
                        if (trailing != null) ...[
                          const SizedBox(width: AppSpacing.space8),
                          trailing!,
                        ],
                      ],
                    ),
          ),
          Padding(padding: contentPadding, child: child),
        ],
      ),
    );
  }

  Widget _buildTitle(BuildContext context, ColorScheme colors) {
    final text = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style:
          emphasis == AnalysisSectionEmphasis.primary
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
            key: const ValueKey('analysis-section-title-action'),
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
                      size: titleActionIconSize,
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
