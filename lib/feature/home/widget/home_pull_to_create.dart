import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';

/// 监听首页流水的下拉越界手势：拖动越过阈值后松手触发 [onTrigger]，
/// 越界区域内渐显提示文案。要求子树滚动视图使用 Bouncing 物理。
class HomePullToCreate extends StatefulWidget {
  const HomePullToCreate({
    required this.onTrigger,
    required this.child,
    super.key,
  });

  final VoidCallback onTrigger;
  final Widget child;

  @override
  State<HomePullToCreate> createState() => _HomePullToCreateState();
}

class _HomePullToCreateState extends State<HomePullToCreate> {
  static const _triggerExtent = 72.0;

  final _pulledExtent = ValueNotifier<double>(0);
  bool _dragging = false;

  @override
  void dispose() {
    _pulledExtent.dispose();
    super.dispose();
  }

  bool _handleNotification(ScrollNotification notification) {
    if (notification.depth != 0) {
      return false;
    }
    switch (notification) {
      case ScrollStartNotification(:final dragDetails):
        _dragging = dragDetails != null;
        _pulledExtent.value = 0;
      case ScrollUpdateNotification(:final dragDetails, :final metrics):
        if (dragDetails != null) {
          _dragging = true;
          _pulledExtent.value = metrics.pixels < 0 ? -metrics.pixels : 0;
        } else {
          _settleDrag();
        }
      case ScrollEndNotification():
        _settleDrag();
    }
    return false;
  }

  void _settleDrag() {
    final shouldTrigger = _dragging && _pulledExtent.value >= _triggerExtent;
    _dragging = false;
    _pulledExtent.value = 0;
    if (shouldTrigger) {
      widget.onTrigger();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<double>(
            valueListenable: _pulledExtent,
            builder: (context, pulled, _) {
              if (pulled <= 0) {
                return const SizedBox.shrink();
              }
              return _PullHint(
                extent: pulled,
                progress: (pulled / _triggerExtent).clamp(0.0, 1.0),
                armed: pulled >= _triggerExtent,
              );
            },
          ),
        ),
        NotificationListener<ScrollNotification>(
          onNotification: _handleNotification,
          child: widget.child,
        ),
      ],
    );
  }
}

class _PullHint extends StatelessWidget {
  const _PullHint({
    required this.extent,
    required this.progress,
    required this.armed,
  });

  final double extent;
  final double progress;
  final bool armed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = armed ? colors.primary : colors.onSurfaceVariant;

    return SizedBox(
      height: extent,
      child: Opacity(
        opacity: progress,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(RemixIcons.add_circle_line, size: 18, color: color),
              const SizedBox(width: AppSpacing.space6),
              Text(
                armed ? '松开新增交易' : '下拉新增交易',
                style: context.appTextStyles.listSupporting.copyWith(
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
