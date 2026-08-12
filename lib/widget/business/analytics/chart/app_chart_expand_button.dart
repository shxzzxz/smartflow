import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../../design_system/token/chart.dart';
import '../../../../design_system/token/component.dart';
import '../../../../design_system/token/spacing.dart';

/// 绘图区右上角的横屏放大按钮。
///
/// 视觉尺寸与触控尺寸分离：视觉上保持轻量，不遮挡数据；触控区域仍满足
/// 可点击性要求，但不再机械套用 48 的通用控件高度。
class AppChartExpandButton extends StatelessWidget {
  const AppChartExpandButton({
    required this.tooltip,
    required this.onTap,
    super.key,
  });

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: AppChartGeometry.expandButtonHitSize,
            height: AppChartGeometry.expandButtonHitSize,
            child: Center(
              child: Container(
                width: AppChartGeometry.expandButtonVisualSize,
                height: AppChartGeometry.expandButtonVisualSize,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLowest.withValues(alpha: .92),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.outlineVariant.withValues(
                      alpha: AppComponentTokens.mutedOutlineOpacity,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(
                        alpha: AppComponentTokens.controlOverlayOpacity,
                      ),
                      blurRadius: AppSpacing.space4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  RemixIcons.fullscreen_line,
                  size: AppChartGeometry.expandIconSize,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
