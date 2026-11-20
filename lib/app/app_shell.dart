import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/shared/app_settings_store.dart';
import '../design_system/token/component.dart';
import '../design_system/widget/app_bottom_navigation_bar.dart';
import '../design_system/widget/app_bottom_navigation_layout_scope.dart';
import '../feature/home/view_model/home_view_model.dart';
import '../feature/shared/view_model/app_settings_view_model.dart';
import '../design_system/widget/app_scaffold.dart';

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

    return AppScaffold(
      extendBody: showsBottomNavigation,
      // Scaffold normally adds the bottom bar's height to the body inset. The
      // navigation always overlays the page, so keep only the system safe-area
      // inset and let the shell layout scope provide content clearance.
      body: showsBottomNavigation
          ? MediaQuery(data: shellMediaQuery, child: scopedBody)
          : scopedBody,
      bottomNavigationBar: !showsBottomNavigation
          ? null
          : AppBottomNavigationBar(
              style: settings.bottomNavigationStyle,
              selectedIndex: selectedIndex,
              showLabels: settings.showBottomNavLabels,
              onDestinationSelected: (index) => context.go(
                const [
                  '/',
                  '/calendar',
                  '/account',
                  '/statistics',
                  '/profile',
                ][index],
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
