import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../token/component.dart';
import '../token/radius.dart';
import '../token/spacing.dart';
import 'app_segmented_control.dart';

/// 滑动胶囊分段控件：浅色轨道内等宽格子，选中胶囊滑动切换。
/// 比 [AppSegmentedControl] 更紧凑，用于图表卡片等空间敏感场景。
class AppSlidingSegmentedControl<T> extends StatelessWidget {
  const AppSlidingSegmentedControl({
    required this.segments,
    required this.selected,
    required this.onChanged,
    super.key,
  }) : assert(segments.length >= 2, '分段控件至少需要两个选项');

  final List<AppSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  static const _slideDuration = Duration(milliseconds: 200);
  static const _slideCurve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selectedStyle = context.appTextStyles
        .quickActionLabel(selected: true)
        .copyWith(color: colors.onSurface);
    final unselectedStyle = context.appTextStyles
        .quickActionLabel(selected: false)
        .copyWith(color: colors.onSurfaceVariant);
    final cellSize = _measureCell(context, selectedStyle);
    final selectedIndex = segments.indexWhere(
      (segment) => segment.value == selected,
    );
    assert(selectedIndex >= 0, '选中值必须在 segments 内');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.radiusFull),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space2),
        child: SizedBox(
          width: cellSize.width * segments.length,
          height: cellSize.height,
          child: Stack(
            children: [
              AnimatedPositionedDirectional(
                duration: _slideDuration,
                curve: _slideCurve,
                start: cellSize.width * math.max(0, selectedIndex),
                width: cellSize.width,
                height: cellSize.height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppRadius.radiusFull),
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
                ),
              ),
              Row(
                children: [
                  for (final segment in segments)
                    _SegmentCell(
                      label: segment.label,
                      width: cellSize.width,
                      selected: segment.value == selected,
                      style:
                          segment.value == selected
                              ? selectedStyle
                              : unselectedStyle,
                      onTap: () => onChanged(segment.value),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 以选中态字重测量最宽标签，等宽格子保证胶囊定位与切换时布局稳定。
  Size _measureCell(BuildContext context, TextStyle style) {
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var width = 0.0;
    var height = 0.0;
    for (final segment in segments) {
      final painter = TextPainter(
        text: TextSpan(text: segment.label, style: style),
        textDirection: direction,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      width = math.max(width, painter.width);
      height = math.max(height, painter.height);
      painter.dispose();
    }
    return Size(
      width + AppSpacing.space10 * 2,
      math.max(AppSpacing.space28, height + AppSpacing.space6 * 2),
    );
  }
}

class _SegmentCell extends StatelessWidget {
  const _SegmentCell({
    required this.label,
    required this.width,
    required this.selected,
    required this.style,
    required this.onTap,
  });

  final String label;
  final double width;
  final bool selected;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: double.infinity,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: AppSlidingSegmentedControl._slideDuration,
              curve: AppSlidingSegmentedControl._slideCurve,
              style: style,
              child: Text(label, maxLines: 1),
            ),
          ),
        ),
      ),
    );
  }
}
