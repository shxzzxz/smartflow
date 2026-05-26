import 'package:flutter/material.dart';

import '../token/elevation.dart';
import '../token/radius.dart';

class AppSurface extends StatelessWidget {
  const AppSurface({
    required this.child,
    super.key,
    this.border = false,
    this.borderRadius = AppRadius.radiusLg,
  });

  final Widget child;
  final bool border;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(borderRadius);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: radius,
        border:
            border
                ? Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.55),
                )
                : null,
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(
              alpha: AppElevation.surfaceShadowOpacity,
            ),
            blurRadius: AppElevation.surfaceShadowBlur,
            offset: AppElevation.surfaceShadowOffset,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: child,
      ),
    );
  }
}
