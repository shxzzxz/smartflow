import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../token/spacing.dart';

enum AppEmptyStateLayout { stacked, inline }

/// Shared content structure for empty panels and compact empty rows.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.title,
    this.icon,
    this.message,
    this.action,
    this.layout = AppEmptyStateLayout.stacked,
    super.key,
  });

  final String title;
  final Widget? icon;
  final String? message;
  final Widget? action;
  final AppEmptyStateLayout layout;

  @override
  Widget build(BuildContext context) {
    final inline = layout == AppEmptyStateLayout.inline;
    final textAlign = inline ? TextAlign.start : TextAlign.center;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: inline
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: textAlign,
          style: context.appTextStyles.listTitle,
        ),
        if (message case final message?) ...[
          const SizedBox(height: AppSpacing.space4),
          Text(
            message,
            textAlign: textAlign,
            style: context.appTextStyles.listSupporting,
          ),
        ],
        if (action case final action?) ...[
          const SizedBox(height: AppSpacing.space12),
          action,
        ],
      ],
    );

    return Padding(
      padding: EdgeInsets.all(inline ? AppSpacing.space20 : AppSpacing.space24),
      child: switch (layout) {
        AppEmptyStateLayout.stacked => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon case final icon?) ...[
              IconTheme.merge(
                data: IconThemeData(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: AppSpacing.space40,
                ),
                child: icon,
              ),
              const SizedBox(height: AppSpacing.space12),
            ],
            content,
          ],
        ),
        AppEmptyStateLayout.inline => Row(
          children: [
            if (icon case final icon?) ...[
              IconTheme.merge(
                data: IconThemeData(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: AppSpacing.space24,
                ),
                child: icon,
              ),
              const SizedBox(width: AppSpacing.space12),
            ],
            Expanded(child: content),
          ],
        ),
      },
    );
  }
}
