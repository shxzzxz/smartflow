import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../design_system/theme/app_text_styles.dart';
import '../design_system/token/spacing.dart';
import '../feature/shared/view_model/app_settings_view_model.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final selectedIndex = _selectedIndex(context);
    final showLabels =
        ref.watch(appSettingsViewModelProvider).value?.showBottomNavLabels ??
        true;

    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            border: Border(
              top: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space8,
            vertical: AppSpacing.space8,
          ),
          child: Row(
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
          ),
        ),
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
              Icon(selected ? selectedIcon : icon, color: color, size: 22),
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
