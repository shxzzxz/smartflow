import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../application/shared/app_glass_settings.dart';
import '../theme/app_appearance_values.dart';
import '../theme/app_chrome_theme.dart';
import '../token/component.dart';
import '../token/elevation.dart';
import '../token/radius.dart';

enum AppFrostedSurfaceVariant { background, floating }

/// 背景玻璃与悬浮玻璃分别模糊各自的底层；悬浮表面更通透，带亮边与柔影。
class AppFrostedSurface extends StatelessWidget {
  const AppFrostedSurface({
    required this.child,
    super.key,
    this.borderRadius = AppRadius.radiusFull,
    this.variant = AppFrostedSurfaceVariant.floating,
    this.glass,
  });

  final Widget child;
  final double borderRadius;
  final AppFrostedSurfaceVariant variant;
  final AppGlassSettings? glass;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final floating = variant == AppFrostedSurfaceVariant.floating;
    final defaults = floating
        ? AppChromeTheme.defaults.headerControlGlass
        : AppChromeTheme.defaults.headerBackgroundGlass;
    final parameters = AppAppearanceValues.resolveGlass(
      glass ?? defaults,
      defaults: defaults,
    );
    final opacityScale =
        parameters.backgroundOpacity / defaults.backgroundOpacity;
    double opacity(double value) =>
        (value * opacityScale).clamp(0, 1).toDouble();
    final radius = BorderRadius.circular(borderRadius);
    final tint = dark
        ? colors.surfaceContainerHighest
        : floating
        ? colors.surfaceContainerLowest
        : colors.surfaceContainerLow;
    final border = (dark ? colors.onSurface : colors.surfaceContainerLowest)
        .withValues(
          alpha: dark
              ? AppComponentTokens.frostedSurfaceDarkBorderOpacity
              : AppComponentTokens.frostedSurfaceBorderOpacity,
        );

    final topOpacity = floating
        ? dark
              ? AppComponentTokens.frostedSurfaceDarkTopOpacity
              : AppComponentTokens.frostedSurfaceTopOpacity
        : dark
        ? AppComponentTokens.frostedBackgroundDarkTopOpacity
        : AppComponentTokens.frostedBackgroundTopOpacity;
    final bottomOpacity = floating
        ? dark
              ? AppComponentTokens.frostedSurfaceDarkBottomOpacity
              : AppComponentTokens.frostedSurfaceBottomOpacity
        : dark
        ? AppComponentTokens.frostedBackgroundDarkBottomOpacity
        : AppComponentTokens.frostedBackgroundBottomOpacity;
    final blurSigma = parameters.blurSigma;
    final blur = ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma);
    final surface = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: floating || parameters.saturation != 1
            ? ui.ImageFilter.compose(
                outer: ColorFilter.saturation(parameters.saturation),
                inner: blur,
              )
            : blur,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: floating
                ? Border.all(
                    color: border,
                    width: AppComponentTokens.outlineWidth,
                  )
                : Border(
                    bottom: BorderSide(
                      color: colors.outlineVariant.withValues(
                        alpha: AppComponentTokens.frostedBackgroundEdgeOpacity,
                      ),
                      width: AppComponentTokens.outlineWidth,
                    ),
                  ),
            gradient: LinearGradient(
              begin: floating ? Alignment.topLeft : Alignment.topCenter,
              end: floating ? Alignment.bottomRight : Alignment.bottomCenter,
              colors: [
                tint.withValues(alpha: opacity(topOpacity)),
                if (floating)
                  tint.withValues(
                    alpha: opacity(
                      dark
                          ? AppComponentTokens.frostedSurfaceDarkMiddleOpacity
                          : AppComponentTokens.frostedSurfaceMiddleOpacity,
                    ),
                  ),
                tint.withValues(alpha: opacity(bottomOpacity)),
              ],
            ),
          ),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
    if (!floating || parameters.shadowOpacity == 0) return surface;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: parameters.shadowOpacity),
            blurRadius: AppElevation.frostedShadowBlur,
            offset: AppElevation.frostedShadowOffset,
            blurStyle: ui.BlurStyle.outer,
          ),
        ],
      ),
      child: surface,
    );
  }
}
