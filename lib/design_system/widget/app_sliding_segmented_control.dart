import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../token/component.dart';
import '../token/radius.dart';
import '../token/spacing.dart';
import 'app_frosted_surface.dart';
import 'app_header_appearance_scope.dart';
import 'app_header_control_surface.dart';
import 'app_header_select_button.dart';
import 'app_select.dart';

enum AppSegmentedControlVariant { filled, frosted, header, adaptiveHeader }

class AppSegment<T> {
  const AppSegment({required this.value, required this.label});

  final T value;
  final String label;
}

/// 滑动胶囊分段控件：浅色轨道内等宽格子，选中胶囊滑动切换。
/// 用于筛选、表单和图表卡片；[onChanged] 为空时禁用交互。
class AppSlidingSegmentedControl<T> extends StatelessWidget {
  const AppSlidingSegmentedControl({
    required this.segments,
    required this.selected,
    required this.onChanged,
    super.key,
    this.textStyle,
    this.variant = AppSegmentedControlVariant.filled,
  }) : assert(segments.length >= 2, '分段控件至少需要两个选项');

  final List<AppSegment<T>> segments;
  final T selected;
  final ValueChanged<T>? onChanged;
  final TextStyle? textStyle;
  final AppSegmentedControlVariant variant;

  static const _slideDuration = Duration(milliseconds: 200);
  static const _slideCurve = Curves.easeOutCubic;

  bool get _isHeader =>
      variant == AppSegmentedControlVariant.header ||
      variant == AppSegmentedControlVariant.adaptiveHeader;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final frosted =
        variant == AppSegmentedControlVariant.frosted ||
        (_isHeader && AppHeaderAppearanceScope.of(context).usesGlassHeader);
    final headerTypography = _isHeader || frosted;
    final selectedStyle =
        (textStyle ??
                (headerTypography
                    ? context.appTextStyles.segmentedControlLabel(
                        selected: true,
                      )
                    : context.appTextStyles.quickActionLabel(selected: true)))
            .copyWith(
              color: headerTypography ? colors.primary : colors.onSurface,
            );
    final unselectedStyle =
        (textStyle ??
                (headerTypography
                    ? context.appTextStyles.segmentedControlLabel(
                        selected: false,
                      )
                    : context.appTextStyles.quickActionLabel(selected: false)))
            .copyWith(color: colors.onSurfaceVariant);
    final cellSize = _measureCell(context, selectedStyle);

    if (variant == AppSegmentedControlVariant.adaptiveHeader) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width =
              cellSize.width * segments.length + AppSpacing.space2 * 2;
          if (width > constraints.maxWidth) {
            final current = segments.firstWhere(
              (segment) => segment.value == selected,
            );
            return AppHeaderControlSurface(
              child: AppHeaderSelectButton<T>(
                label: current.label,
                tooltip: '选择：${current.label}',
                value: selected,
                onChanged: onChanged,
                options: [
                  for (final segment in segments)
                    AppSelectOption(value: segment.value, label: segment.label),
                ],
                maxWidth: constraints.maxWidth,
                showDropdownIcon: true,
                textStyle: selectedStyle,
              ),
            );
          }
          return _buildControl(
            context,
            cellSize,
            selectedStyle,
            unselectedStyle,
            frosted,
          );
        },
      );
    }
    return _buildControl(
      context,
      cellSize,
      selectedStyle,
      unselectedStyle,
      frosted,
    );
  }

  Widget _buildControl(
    BuildContext context,
    Size cellSize,
    TextStyle selectedStyle,
    TextStyle unselectedStyle,
    bool frosted,
  ) {
    final colors = Theme.of(context).colorScheme;
    final headerTypography = _isHeader || frosted;
    final selectedIndex = segments.indexWhere(
      (segment) => segment.value == selected,
    );
    assert(selectedIndex >= 0, '选中值必须在 segments 内');
    final control = Padding(
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
                  color: frosted
                      ? colors.primary.withValues(
                          alpha: AppComponentTokens.selectedContainerOpacity,
                        )
                      : colors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                  boxShadow: headerTypography
                      ? null
                      : [
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
                    style: segment.value == selected
                        ? selectedStyle
                        : unselectedStyle,
                    onTap: onChanged == null
                        ? null
                        : () => onChanged?.call(segment.value),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (frosted) {
      return _isHeader
          ? AppHeaderControlSurface(child: control)
          : AppFrostedSurface(child: control);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.radiusFull),
      ),
      child: control,
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
    final horizontalPadding =
        variant == AppSegmentedControlVariant.adaptiveHeader
        ? AppSpacing.space6
        : AppSpacing.space10;
    return Size(
      width + horizontalPadding * 2,
      math.max(
        variant != AppSegmentedControlVariant.filled
            ? AppSpacing.space32
            : AppSpacing.space28,
        height + AppSpacing.space6 * 2,
      ),
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.radiusFull),
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
      ),
    );
  }
}
