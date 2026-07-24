import 'package:flutter/material.dart';

import '../token/component.dart';
import '../token/elevation.dart';
import '../token/radius.dart';

class AppSurface extends StatelessWidget {
  const AppSurface({
    required this.child,
    super.key,
    this.border = false,
    this.borderRadius = AppRadius.radiusXl,
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
                  color: colors.outlineVariant.withValues(
                    alpha: AppComponentTokens.mutedOutlineOpacity,
                  ),
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
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
