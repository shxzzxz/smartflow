import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../../design_system/theme/app_text_styles.dart';
import '../../../../design_system/token/component.dart';
import '../../../../design_system/token/radius.dart';
import '../../../../design_system/token/spacing.dart';
import '../../../../design_system/token/typography.dart';

class InsuranceOverviewHero extends StatelessWidget {
  const InsuranceOverviewHero({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final gradientEnd =
        Color.lerp(colors.primary, colors.primaryContainer, 0.72) ??
        colors.primary;
    return Semantics(
      label: '为家人多一份保障，安心生活每一天',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.space20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.radiusXl),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.primary, gradientEnd],
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '为家人多一份保障',
                    style: context.appTextStyles.onPrimaryTinyStrong.copyWith(
                      fontSize: AppTypography.fontSizeMd,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space6),
                  Text(
                    '安心生活每一天',
                    style: context.appTextStyles.onPrimarySupporting,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.space16),
            Container(
              width: AppSpacing.space48,
              height: AppSpacing.space48,
              decoration: BoxDecoration(
                color: colors.onPrimary.withValues(
                  alpha: AppComponentTokens.selectedContainerOpacity,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                RemixIcons.shield_check_fill,
                color: colors.onPrimary,
                size: AppSpacing.space28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
