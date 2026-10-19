import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../theme/app_theme_extension.dart';
import '../token/component.dart';
import '../token/radius.dart';
import '../token/spacing.dart';

enum AppStatusTone { neutral, primary, info, success, warning, danger }

enum AppStatusBadgeSize { detail, compact }

@immutable
class AppStatusBadgePresentation {
  const AppStatusBadgePresentation({required this.label, required this.tone});

  final String label;
  final AppStatusTone tone;
}

/// Compact status label shared by detail summaries and list rows.
class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    required this.presentation,
    this.size = AppStatusBadgeSize.detail,
    super.key,
  });

  final AppStatusBadgePresentation presentation;
  final AppStatusBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final compact = size == AppStatusBadgeSize.compact;
    final color = appStatusToneColor(context, presentation.tone);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.space6 : AppSpacing.space8,
        vertical: AppSpacing.space2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: AppComponentTokens.statusBackgroundOpacity,
        ),
        borderRadius: BorderRadius.circular(
          compact ? AppRadius.radiusMd : AppRadius.radiusFull,
        ),
      ),
      child: Text(
        presentation.label,
        style:
            (compact
                    ? context.appTextStyles.badgeLabel
                    : context.appTextStyles.listSupporting)
                .copyWith(color: color),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

Color appStatusToneColor(BuildContext context, AppStatusTone tone) {
  final colors = Theme.of(context).colorScheme;
  final extension = Theme.of(context).extension<AppThemeExtension>()!;
  return switch (tone) {
    AppStatusTone.neutral => colors.onSurfaceVariant,
    AppStatusTone.primary => colors.primary,
    AppStatusTone.info => extension.info,
    AppStatusTone.success => extension.success,
    AppStatusTone.warning => extension.warning,
    AppStatusTone.danger => extension.danger,
  };
}
