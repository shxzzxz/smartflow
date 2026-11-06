import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/insurance/insurance_query_api.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/token/component.dart';

class MemberAvatarView extends StatelessWidget {
  const MemberAvatarView({
    required this.preset,
    super.key,
    this.size = 48,
    this.selected = false,
  });

  final MemberAvatarPreset preset;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = memberAvatarPresetColor(context, preset);
    return Semantics(
      image: true,
      label: '${preset.label}头像',
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(selected ? 3 : 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: selected ? Border.all(color: colors.primary, width: 2) : null,
        ),
        child: ClipOval(
          child: ColoredBox(
            color: color.withValues(
              alpha: AppComponentTokens.selectedContainerOpacity,
            ),
            child: Center(
              child: Icon(
                memberAvatarPresetIcon(preset),
                size: size * 0.52,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

IconData memberAvatarPresetIcon(MemberAvatarPreset preset) {
  return switch (preset) {
    MemberAvatarPreset.blue => RemixIcons.user_3_fill,
    MemberAvatarPreset.green => RemixIcons.user_smile_fill,
    MemberAvatarPreset.orange => RemixIcons.user_star_fill,
    MemberAvatarPreset.pink => RemixIcons.user_heart_fill,
    MemberAvatarPreset.purple => RemixIcons.user_5_fill,
    MemberAvatarPreset.teal => RemixIcons.user_6_fill,
  };
}

Color memberAvatarPresetColor(BuildContext context, MemberAvatarPreset preset) {
  final colors = Theme.of(context).colorScheme;
  final extension =
      Theme.of(context).extension<AppThemeExtension>() ??
      AppThemeExtension.light();
  return switch (preset) {
    MemberAvatarPreset.blue => colors.primary,
    MemberAvatarPreset.green => extension.success,
    MemberAvatarPreset.orange => extension.warning,
    MemberAvatarPreset.pink => extension.chart5,
    MemberAvatarPreset.purple => extension.chart7,
    MemberAvatarPreset.teal => extension.chart3,
  };
}
