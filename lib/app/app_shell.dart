import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../application/shared/app_settings_store.dart';
import '../design_system/theme/app_text_styles.dart';
import '../design_system/token/component.dart';
import '../design_system/token/elevation.dart';
import '../design_system/token/spacing.dart';
import '../design_system/widget/app_bottom_navigation_layout_scope.dart';
import '../feature/home/view_model/home_view_model.dart';
import '../feature/shared/view_model/app_settings_view_model.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _selectedIndex(context);
    final isHomeBatchMode =
        selectedIndex == 0 && ref.watch(homeBatchModeProvider);
    final settings =
        ref.watch(appSettingsViewModelProvider).value ?? const AppSettings();
    final showsBottomNavigation = !isHomeBatchMode;
    final usesFrostedSurface =
        showsBottomNavigation &&
        settings.bottomNavigationStyle == BottomNavigationStyle.frostedGlass;
    final shellMediaQuery = MediaQuery.of(context);
    final navigationLayout = showsBottomNavigation
        ? AppBottomNavigationLayout(
            contentInset: usesFrostedSurface
                ? AppComponentTokens.frostedNavigationBarClearance
                : AppComponentTokens.navigationBarHeight,
            floatingActionInset: usesFrostedSurface
                ? AppComponentTokens.frostedNavigationBarClearance
                : AppComponentTokens.navigationBarHeight,
          )
        : AppBottomNavigationLayout.none;
    final scopedBody = AppBottomNavigationLayoutScope(
      layout: navigationLayout,
      child: child,
    );

    return Scaffold(
      extendBody: showsBottomNavigation,
      // Scaffold normally adds the bottom bar's height to the body inset. The
      // navigation always overlays the page, so keep only the system safe-area
      // inset and let the shell layout scope provide content clearance.
      body: showsBottomNavigation
          ? MediaQuery(data: shellMediaQuery, child: scopedBody)
          : scopedBody,
      bottomNavigationBar: !showsBottomNavigation
          ? null
          : _AppBottomNavigationBar(
              style: settings.bottomNavigationStyle,
              selectedIndex: selectedIndex,
              showLabels: settings.showBottomNavLabels,
            ),
    );
  }

  int _selectedIndex(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/calendar')) {
      return 1;
    }
    if (path.startsWith('/account')) {
      return 2;
    }
    if (path.startsWith('/statistics')) {
      return 3;
    }
    if (path.startsWith('/profile')) {
      return 4;
    }
    return 0;
  }
}

class _AppBottomNavigationBar extends StatelessWidget {
  const _AppBottomNavigationBar({
    required this.style,
    required this.selectedIndex,
    required this.showLabels,
  });

  final BottomNavigationStyle style;
  final int selectedIndex;
  final bool showLabels;

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
          onTap: () => context.go('/'),
        ),
        _BottomNavItem(
          icon: RemixIcons.calendar_line,
          selectedIcon: RemixIcons.calendar_fill,
          label: '日历',
          showLabel: showLabels,
          selected: selectedIndex == 1,
          onTap: () => context.go('/calendar'),
        ),
        _BottomNavItem(
          icon: RemixIcons.wallet_3_line,
          selectedIcon: RemixIcons.wallet_3_fill,
          label: '资产',
          showLabel: showLabels,
          selected: selectedIndex == 2,
          onTap: () => context.go('/account'),
        ),
        _BottomNavItem(
          icon: RemixIcons.pie_chart_line,
          selectedIcon: RemixIcons.pie_chart_fill,
          label: '统计',
          showLabel: showLabels,
          selected: selectedIndex == 3,
          onTap: () => context.go('/statistics'),
        ),
        _BottomNavItem(
          icon: RemixIcons.user_3_line,
          selectedIcon: RemixIcons.user_3_fill,
          label: '我的',
          showLabel: showLabels,
          selected: selectedIndex == 4,
          onTap: () => context.go('/profile'),
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
    final colors = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(
      AppComponentTokens.frostedNavigationBarRadius,
    );
    final backdropFilter = ImageFilter.compose(
      outer: ColorFilter.saturation(
        AppComponentTokens.frostedNavigationBarSaturation,
      ),
      inner: ImageFilter.blur(
        sigmaX: AppComponentTokens.frostedNavigationBarBlurSigma,
        sigmaY: AppComponentTokens.frostedNavigationBarBlurSigma,
      ),
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
                color: colors.shadow.withValues(
                  alpha: AppComponentTokens.frostedNavigationBarShadowOpacity,
                ),
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
                    alpha: AppComponentTokens
                        .frostedNavigationBarBackgroundOpacity,
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = selected ? colors.primary : colors.onSurfaceVariant;

    return Expanded(
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
    );
  }
}
