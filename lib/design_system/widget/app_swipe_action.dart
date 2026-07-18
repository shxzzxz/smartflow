import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../token/spacing.dart';

enum AppSwipeActionTone { primary, danger }

class AppSwipeActionItem {
  const AppSwipeActionItem({
    required this.label,
    required this.icon,
    required this.onTriggered,
    this.tone = AppSwipeActionTone.primary,
  });

  final String label;
  final IconData icon;
  final FutureOr<void> Function() onTriggered;
  final AppSwipeActionTone tone;
}

class AppSwipeAction extends StatefulWidget {
  const AppSwipeAction({
    required this.dismissibleKey,
    required this.label,
    required this.icon,
    required this.onTriggered,
    required this.child,
    super.key,
    this.tone = AppSwipeActionTone.primary,
    this.secondaryAction,
  });

  final Key dismissibleKey;
  final String label;
  final IconData icon;
  final FutureOr<void> Function() onTriggered;
  final Widget child;
  final AppSwipeActionTone tone;
  final AppSwipeActionItem? secondaryAction;

  @override
  State<AppSwipeAction> createState() => _AppSwipeActionState();
}

class _AppSwipeActionState extends State<AppSwipeAction> {
  static const _primaryThreshold = 0.25;
  static const _secondaryThreshold = 0.65;
  static const _resetDuration = Duration(milliseconds: 180);

  double _dragExtent = 0;
  double _availableWidth = 1;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _availableWidth = constraints.maxWidth;
        final action = _activeAction;
        return ClipRect(
          key: widget.dismissibleKey,
          child: Stack(
            children: [
              Positioned.fill(
                child: _ActionBackground(
                  label: action.label,
                  icon: action.icon,
                  tone: action.tone,
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) {
                  setState(() => _dragging = true);
                },
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _dragExtent = (_dragExtent + details.delta.dx).clamp(
                      0,
                      _availableWidth,
                    );
                  });
                },
                onHorizontalDragEnd: (_) => _finishDrag(),
                onHorizontalDragCancel: _reset,
                child: AnimatedContainer(
                  duration: _dragging ? Duration.zero : _resetDuration,
                  transform: Matrix4.translationValues(_dragExtent, 0, 0),
                  child: widget.child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  AppSwipeActionItem get _primaryAction => AppSwipeActionItem(
    label: widget.label,
    icon: widget.icon,
    onTriggered: widget.onTriggered,
    tone: widget.tone,
  );

  AppSwipeActionItem get _activeAction {
    final secondary = widget.secondaryAction;
    if (secondary != null && _dragFraction >= _secondaryThreshold) {
      return secondary;
    }
    return _primaryAction;
  }

  double get _dragFraction => _dragExtent / _availableWidth;

  Future<void> _finishDrag() async {
    final fraction = _dragFraction;
    final action = switch (widget.secondaryAction) {
      final secondary? when fraction >= _secondaryThreshold => secondary,
      _ when fraction >= _primaryThreshold => _primaryAction,
      _ => null,
    };
    _reset();
    if (action != null) await action.onTriggered();
  }

  void _reset() {
    if (!mounted) return;
    setState(() {
      _dragging = false;
      _dragExtent = 0;
    });
  }
}

class _ActionBackground extends StatelessWidget {
  const _ActionBackground({
    required this.label,
    required this.icon,
    required this.tone,
  });

  final String label;
  final IconData icon;
  final AppSwipeActionTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final styles = context.appTextStyles;
    final (backgroundColor, foregroundColor) = switch (tone) {
      AppSwipeActionTone.primary => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      AppSwipeActionTone.danger => (
        colors.errorContainer,
        colors.onErrorContainer,
      ),
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        return DecoratedBox(
          decoration: BoxDecoration(color: backgroundColor),
          child: Align(
            alignment: Alignment.centerLeft,
            child:
                constraints.maxWidth < AppSpacing.space20 * 4
                    ? const SizedBox.shrink()
                    : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space20,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: AppSpacing.space20,
                            color: foregroundColor,
                          ),
                          const SizedBox(width: AppSpacing.space8),
                          Text(
                            label,
                            style: styles.formLabel.copyWith(
                              color: foregroundColor,
                            ),
                          ),
                        ],
                      ),
                    ),
          ),
        );
      },
    );
  }
}
