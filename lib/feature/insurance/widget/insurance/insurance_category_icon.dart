import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../../application/insurance/insurance_query_api.dart';
import '../../../../design_system/theme/app_theme_extension.dart';
import '../../../../design_system/token/component.dart';
import '../../../../design_system/token/radius.dart';

class InsuranceCategoryIcon extends StatelessWidget {
  const InsuranceCategoryIcon.commercial({
    required CommercialInsuranceCategory category,
    super.key,
    this.size = 44,
  }) : _category = category,
       _socialInsuranceType = null,
       _responsibilityKind = null;

  const InsuranceCategoryIcon.social({
    required SocialInsuranceType insuranceType,
    super.key,
    this.size = 44,
  }) : _socialInsuranceType = insuranceType,
       _category = null,
       _responsibilityKind = null;

  const InsuranceCategoryIcon.responsibility({
    required ResponsibilityKind kind,
    super.key,
    this.size = 44,
  }) : _responsibilityKind = kind,
       _category = null,
       _socialInsuranceType = null;

  final CommercialInsuranceCategory? _category;
  final SocialInsuranceType? _socialInsuranceType;
  final ResponsibilityKind? _responsibilityKind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final extension =
        Theme.of(context).extension<AppThemeExtension>() ??
        AppThemeExtension.light();
    final visual = _visual(colors, extension);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: visual.color.withValues(
          alpha: AppComponentTokens.selectedContainerOpacity,
        ),
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
      ),
      child: Icon(visual.icon, size: size * 0.52, color: visual.color),
    );
  }

  _InsuranceVisual _visual(ColorScheme colors, AppThemeExtension extension) {
    final category = _category;
    if (category != null) {
      return switch (category) {
        CommercialInsuranceCategory.medical => _InsuranceVisual(
          RemixIcons.heart_pulse_fill,
          extension.chart5,
        ),
        CommercialInsuranceCategory.criticalIllness => _InsuranceVisual(
          RemixIcons.shield_cross_fill,
          colors.primary,
        ),
        CommercialInsuranceCategory.accident => _InsuranceVisual(
          RemixIcons.umbrella_fill,
          extension.info,
        ),
        CommercialInsuranceCategory.life => _InsuranceVisual(
          RemixIcons.shield_check_fill,
          extension.success,
        ),
        CommercialInsuranceCategory.other => _InsuranceVisual(
          RemixIcons.shield_keyhole_fill,
          colors.onSurfaceVariant,
        ),
      };
    }

    final socialInsuranceType = _socialInsuranceType;
    if (socialInsuranceType != null) {
      return switch (socialInsuranceType) {
        SocialInsuranceType.medical => _InsuranceVisual(
          RemixIcons.hospital_fill,
          extension.chart3,
        ),
        SocialInsuranceType.pension => _InsuranceVisual(
          RemixIcons.hand_heart_fill,
          extension.warning,
        ),
        SocialInsuranceType.workInjury => _InsuranceVisual(
          RemixIcons.shield_cross_fill,
          extension.info,
        ),
        SocialInsuranceType.maternity => _InsuranceVisual(
          RemixIcons.heart_pulse_fill,
          extension.chart5,
        ),
        SocialInsuranceType.unemployment => _InsuranceVisual(
          RemixIcons.briefcase_fill,
          colors.onSurfaceVariant,
        ),
      };
    }

    return switch (_responsibilityKind ?? ResponsibilityKind.other) {
      ResponsibilityKind.medical => _InsuranceVisual(
        RemixIcons.heart_pulse_fill,
        extension.chart5,
      ),
      ResponsibilityKind.criticalIllness => _InsuranceVisual(
        RemixIcons.shield_cross_fill,
        colors.primary,
      ),
      ResponsibilityKind.accident => _InsuranceVisual(
        RemixIcons.umbrella_fill,
        extension.info,
      ),
      ResponsibilityKind.life => _InsuranceVisual(
        RemixIcons.shield_check_fill,
        extension.success,
      ),
      ResponsibilityKind.disability => _InsuranceVisual(
        RemixIcons.user_heart_fill,
        extension.warning,
      ),
      ResponsibilityKind.other => _InsuranceVisual(
        RemixIcons.shield_keyhole_fill,
        colors.onSurfaceVariant,
      ),
    };
  }
}

class _InsuranceVisual {
  const _InsuranceVisual(this.icon, this.color);

  final IconData icon;
  final Color color;
}
