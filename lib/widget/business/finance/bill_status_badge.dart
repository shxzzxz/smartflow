import 'package:flutter/material.dart';

import 'package:smartflow/design_system/theme/app_text_styles.dart';
import 'package:smartflow/design_system/theme/app_theme_extension.dart';
import 'package:smartflow/design_system/token/list.dart';
import 'package:smartflow/design_system/token/radius.dart';
import 'package:smartflow/design_system/token/spacing.dart';

enum BillStatusTone { neutral, primary, warning, success, danger }

class BillStatusBadgePresentation {
  const BillStatusBadgePresentation({required this.label, required this.tone});

  final String label;
  final BillStatusTone tone;
}

class BillStatusBadge extends StatelessWidget {
  const BillStatusBadge({required this.status, super.key});

  final BillStatusBadgePresentation status;

  @override
  Widget build(BuildContext context) {
    final color = billStatusToneColor(context, status.tone);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space6,
        vertical: AppSpacing.space2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppListTokens.statusBackgroundOpacity),
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
      ),
      child: Text(
        status.label,
        style: context.appTextStyles.badgeLabel.copyWith(color: color),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

Color billStatusToneColor(BuildContext context, BillStatusTone tone) {
  final colors = Theme.of(context).colorScheme;
  final extension = Theme.of(context).extension<AppThemeExtension>()!;
  return switch (tone) {
    BillStatusTone.neutral => colors.onSurfaceVariant,
    BillStatusTone.primary => colors.primary,
    BillStatusTone.warning => extension.warning,
    BillStatusTone.success => extension.success,
    BillStatusTone.danger => extension.danger,
  };
}
