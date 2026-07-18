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

class AppSwipeAction extends StatelessWidget {
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

  static const _dismissThreshold = 0.4;

  final Key dismissibleKey;
  final String label;
  final IconData icon;
  final FutureOr<void> Function() onTriggered;
  final Widget child;
  final AppSwipeActionTone tone;
  final AppSwipeActionItem? secondaryAction;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: dismissibleKey,
      direction:
          secondaryAction == null
              ? DismissDirection.startToEnd
              : DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: _dismissThreshold,
        DismissDirection.endToStart: _dismissThreshold,
      },
      background: _ActionBackground(label: label, icon: icon, tone: tone),
      secondaryBackground:
          secondaryAction == null
              ? null
              : _ActionBackground(
                label: secondaryAction!.label,
                icon: secondaryAction!.icon,
                tone: secondaryAction!.tone,
                alignment: Alignment.centerRight,
              ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await onTriggered();
        } else if (direction == DismissDirection.endToStart) {
          await secondaryAction?.onTriggered();
        }
        return false;
      },
      child: child,
    );
  }
}

class _ActionBackground extends StatelessWidget {
  const _ActionBackground({
    required this.label,
    required this.icon,
    required this.tone,
    this.alignment = Alignment.centerLeft,
  });

  final String label;
  final IconData icon;
  final AppSwipeActionTone tone;
  final Alignment alignment;

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
    return DecoratedBox(
      decoration: BoxDecoration(color: backgroundColor),
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: AppSpacing.space20, color: foregroundColor),
              const SizedBox(width: AppSpacing.space8),
              Text(
                label,
                style: styles.formLabel.copyWith(color: foregroundColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
