import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../application/shared/app_appearance_settings.dart';
import '../theme/app_appearance_theme.dart';
import '../token/appearance.dart';

/// 以不透明基底承载页面渐变，路由切换和局部预览不会透出其他页面。
class AppPageBackground extends StatelessWidget {
  const AppPageBackground({required this.child, super.key, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appearance =
        theme.extension<AppAppearanceTheme>() ??
        AppAppearanceTheme(
          gradientColor: theme.colorScheme.primary,
          gradientDepth: 0,
          gradientRange: AppAppearanceTokens.gradientRange,
          backgroundStyle: AppBackgroundStyle.solid,
        );
    return CustomPaint(
      painter: _PageBackgroundPainter(
        background: color ?? theme.colorScheme.surface,
        tint: appearance.gradientColor,
        secondaryTint: appearance.secondaryGradientColor,
        tertiaryTint: appearance.tertiaryGradientColor,
        depth: appearance.gradientDepth,
        range: appearance.gradientRange,
        style: appearance.backgroundStyle,
        maxOpacity: theme.brightness == Brightness.dark
            ? AppAppearanceTokens.darkGradientOpacity
            : AppAppearanceTokens.lightGradientOpacity,
      ),
      child: child,
    );
  }
}

class _PageBackgroundPainter extends CustomPainter {
  const _PageBackgroundPainter({
    required this.background,
    required this.tint,
    required this.secondaryTint,
    required this.tertiaryTint,
    required this.depth,
    required this.range,
    required this.style,
    required this.maxOpacity,
  });

  final Color background;
  final Color tint;
  final Color secondaryTint;
  final Color tertiaryTint;
  final double depth;
  final double range;
  final AppBackgroundStyle style;
  final double maxOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.save();
    canvas.clipRect(bounds);
    canvas.drawRect(bounds, Paint()..color = background);
    if (style != AppBackgroundStyle.solid && depth > 0 && !size.isEmpty) {
      _paintGlow(
        canvas,
        color: tint,
        center: Offset.zero,
        width: size.width * AppAppearanceTokens.primaryGradientWidth,
        height: size.height * range * AppAppearanceTokens.primaryGradientHeight,
        opacity: depth * maxOpacity,
      );
      if (style == AppBackgroundStyle.multiGlow) {
        _paintGlow(
          canvas,
          color: secondaryTint,
          center: Offset(
            size.width,
            size.height * AppAppearanceTokens.secondaryGradientTop,
          ),
          width: size.width * AppAppearanceTokens.secondaryGradientWidth,
          height:
              size.height * range * AppAppearanceTokens.secondaryGradientHeight,
          opacity:
              depth * maxOpacity * AppAppearanceTokens.secondaryGradientOpacity,
        );
        _paintGlow(
          canvas,
          color: tertiaryTint,
          center: Offset(0, size.height),
          width: size.width * AppAppearanceTokens.tertiaryGradientWidth,
          height:
              size.height * range * AppAppearanceTokens.tertiaryGradientHeight,
          opacity:
              depth * maxOpacity * AppAppearanceTokens.tertiaryGradientOpacity,
        );
      }
    }
    canvas.restore();
  }

  void _paintGlow(
    Canvas canvas, {
    required Color color,
    required Offset center,
    required double width,
    required double height,
    required double opacity,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(width, height);
    canvas.drawRect(
      const Rect.fromLTRB(-1, -1, 1, 1),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          1,
          AppAppearanceTokens.gradientOpacityFactors
              .map((factor) => color.withValues(alpha: opacity * factor))
              .toList(growable: false),
          AppAppearanceTokens.gradientStops,
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PageBackgroundPainter oldDelegate) =>
      background != oldDelegate.background ||
      tint != oldDelegate.tint ||
      secondaryTint != oldDelegate.secondaryTint ||
      tertiaryTint != oldDelegate.tertiaryTint ||
      depth != oldDelegate.depth ||
      range != oldDelegate.range ||
      style != oldDelegate.style ||
      maxOpacity != oldDelegate.maxOpacity;
}
