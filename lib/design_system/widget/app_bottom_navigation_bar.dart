import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../application/shared/app_settings_store.dart';
import '../theme/app_chrome_theme.dart';
import '../theme/app_text_styles.dart';
import '../token/component.dart';
import '../token/elevation.dart';
import '../token/spacing.dart';

/// 应用一级页面的底部导航呈现。
class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.style,
    required this.selectedIndex,
    required this.showLabels,
    this.onDestinationSelected,
  });

  final BottomNavigationStyle style;
  final int selectedIndex;
  final bool showLabels;
  final ValueChanged<int>? onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final items = Row(
      children: [
        _BottomNavItem(
          icon: RemixIcons.home_4_line,
          selectedIcon: RemixIcons.home_4_fill,
          label: '首页',
          showLabel: showLabels,
          selected: selectedIndex == 0,
          onTap: onDestinationSelected == null
              ? null
              : () => onDestinationSelected!(0),
        ),
        _BottomNavItem(
          icon: RemixIcons.calendar_line,
          selectedIcon: RemixIcons.calendar_fill,
          label: '日历',
          showLabel: showLabels,
          selected: selectedIndex == 1,
          onTap: onDestinationSelected == null
              ? null
              : () => onDestinationSelected!(1),
        ),
        _BottomNavItem(
          icon: RemixIcons.wallet_3_line,
          selectedIcon: RemixIcons.wallet_3_fill,
          label: '资产',
          showLabel: showLabels,
          selected: selectedIndex == 2,
          onTap: onDestinationSelected == null
              ? null
              : () => onDestinationSelected!(2),
        ),
        _BottomNavItem(
          icon: RemixIcons.pie_chart_line,
          selectedIcon: RemixIcons.pie_chart_fill,
          label: '统计',
          showLabel: showLabels,
          selected: selectedIndex == 3,
          onTap: onDestinationSelected == null
              ? null
              : () => onDestinationSelected!(3),
        ),
        _BottomNavItem(
          icon: RemixIcons.user_3_line,
          selectedIcon: RemixIcons.user_3_fill,
          label: '我的',
          showLabel: showLabels,
          selected: selectedIndex == 4,
          onTap: onDestinationSelected == null
              ? null
              : () => onDestinationSelected!(4),
        ),
      ],
    );

    return switch (style) {
      BottomNavigationStyle.classic => _buildClassic(context, items),
      BottomNavigationStyle.frostedGlass => _buildFrostedGlass(context, items),
    };
  }

  Widget _buildClassic(BuildContext context, Widget items) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey('classic-bottom-navigation'),
        constraints: const BoxConstraints(
          minHeight: AppComponentTokens.navigationBarHeight,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          border: Border(
            top: BorderSide(
              color: colors.outlineVariant.withValues(
                alpha: AppComponentTokens.mutedOutlineOpacity,
              ),
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space8,
          vertical: AppSpacing.space8,
        ),
        child: items,
      ),
    );
  }

  Widget _buildFrostedGlass(BuildContext context, Widget items) {
    final glass = AppChromeTheme.of(context).navigationGlass;
    final colors = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(
      AppComponentTokens.frostedNavigationBarRadius,
    );
    final backdropFilter = ImageFilter.compose(
      outer: ColorFilter.saturation(glass.saturation),
      inner: ImageFilter.blur(sigmaX: glass.blurSigma, sigmaY: glass.blurSigma),
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space16,
          0,
          AppSpacing.space16,
          AppComponentTokens.frostedNavigationBarMargin,
        ),
        child: Container(
          key: const ValueKey('frosted-glass-bottom-navigation'),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: glass.shadowOpacity),
                blurRadius: AppElevation.surfaceShadowBlur,
                offset: AppElevation.surfaceShadowOffset,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: BackdropFilter(
              filter: backdropFilter,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLowest.withValues(
                    alpha: glass.backgroundOpacity,
                  ),
                  borderRadius: borderRadius,
                  border: Border.all(
                    color: colors.outlineVariant.withValues(
                      alpha: AppComponentTokens.mutedOutlineOpacity,
                    ),
                    width: AppComponentTokens.outlineWidth,
                  ),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppComponentTokens.navigationBarHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space8,
                      vertical: AppSpacing.space8,
                    ),
                    child: items,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.showLabel,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool showLabel;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = selected ? colors.primary : colors.onSurfaceVariant;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: showLabel ? null : label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.space8),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: showLabel ? AppSpacing.space4 : AppSpacing.space8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  color: color,
                  size: AppComponentTokens.bottomBarIconSize,
                ),
                if (showLabel) ...[
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    label,
                    style: context.appTextStyles.navigationLabel.copyWith(
                      color: color,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
