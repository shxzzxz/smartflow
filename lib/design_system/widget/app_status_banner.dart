import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../theme/app_theme_extension.dart';
import '../token/list.dart';
import '../token/radius.dart';
import '../token/spacing.dart';

enum AppStatusBannerTone { success, warning, danger, info }

class AppStatusBanner extends StatelessWidget {
  const AppStatusBanner({required this.message, required this.tone, super.key});

  final String message;
  final AppStatusBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final statusColors = Theme.of(context).extension<AppThemeExtension>()!;
    final color = switch (tone) {
      AppStatusBannerTone.success => statusColors.success,
      AppStatusBannerTone.warning => statusColors.warning,
      AppStatusBannerTone.danger => statusColors.danger,
      AppStatusBannerTone.info => statusColors.info,
    };
    final icon = switch (tone) {
      AppStatusBannerTone.success => Icons.check_circle_rounded,
      AppStatusBannerTone.warning => Icons.warning_amber_rounded,
      AppStatusBannerTone.danger => Icons.cancel_rounded,
      AppStatusBannerTone.info => Icons.info_rounded,
    };

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space8,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: AppListTokens.statusBackgroundOpacity),
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        ),
        child: Row(
          children: [
            Icon(icon, size: AppSpacing.space18, color: color),
            const SizedBox(width: AppSpacing.space8),
            Expanded(
              child: Text(
                message,
                style: context.appTextStyles.listSupporting.copyWith(
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
