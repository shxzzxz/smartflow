import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../presentation/log_viewer_presentation.dart';

class LogLevelBadge extends StatelessWidget {
  const LogLevelBadge({required this.level, super.key});

  final Level level;

  @override
  Widget build(BuildContext context) {
    final color = logLevelColor(context, level);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space8,
        vertical: AppSpacing.space2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: AppComponentTokens.statusBackgroundOpacity,
        ),
        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
      ),
      child: Text(
        logLevelLabel(level),
        style: context.appTextStyles.badgeLabel.copyWith(color: color),
      ),
    );
  }
}

Color logLevelColor(BuildContext context, Level level) {
  final theme = Theme.of(context);
  final extension = theme.extension<AppThemeExtension>();
  if (level >= Level.SEVERE) {
    return extension?.danger ?? theme.colorScheme.error;
  }
  if (level >= Level.WARNING) {
    return extension?.warning ?? theme.colorScheme.tertiary;
  }
  if (level >= Level.INFO) {
    return extension?.info ?? theme.colorScheme.primary;
  }
  return theme.colorScheme.onSurfaceVariant;
}
