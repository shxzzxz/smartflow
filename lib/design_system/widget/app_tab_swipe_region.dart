import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../token/header.dart';

/// 内容区左右滑动时切换相邻页签，沿用页面已有的选择状态与回调。
/// [onChanged] 为空时禁用；首尾不循环，子组件的横向手势优先。
class AppTabSwipeRegion<T> extends StatefulWidget {
  const AppTabSwipeRegion({
    required this.values,
    required this.selected,
    required this.onChanged,
    required this.child,
    super.key,
  }) : assert(values.length >= 2);

  final List<T> values;
  final T selected;
  final ValueChanged<T>? onChanged;
  final Widget child;

  @override
  State<AppTabSwipeRegion<T>> createState() => _AppTabSwipeRegionState<T>();
}

class _AppTabSwipeRegionState<T> extends State<AppTabSwipeRegion<T>> {
  double _dragDistance = 0;

  @override
  Widget build(BuildContext context) {
    assert(widget.values.contains(widget.selected), '选中值必须在 values 内');
    final enabled = widget.onChanged != null;
    return Listener(
      // 已识别的拖动被取消时仍会触发 onEnd，先清空距离。
      onPointerCancel: (_) => _dragDistance = 0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: enabled ? (_) => _dragDistance = 0 : null,
        onHorizontalDragUpdate: enabled
            ? (details) => _dragDistance += details.primaryDelta ?? 0
            : null,
        onHorizontalDragEnd: enabled ? (_) => _finishDrag() : null,
        onHorizontalDragCancel: enabled ? () => _dragDistance = 0 : null,
        child: widget.child,
      ),
    );
  }

  void _finishDrag() {
    final distance = _dragDistance;
    _dragDistance = 0;
    if (distance.abs() < AppHeaderTokens.tabSwipeDistance) return;
    final direction = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
    final index = widget.values.indexOf(widget.selected);
    final nextIndex = index + (distance < 0 ? direction : -direction);
    if (index < 0 || nextIndex < 0 || nextIndex >= widget.values.length) return;
    widget.onChanged?.call(widget.values[nextIndex]);
  }
}
