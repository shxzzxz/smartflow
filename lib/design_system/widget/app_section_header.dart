import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../token/spacing.dart';

/// Standard title row for form, settings, and documentation sections.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: styles.groupTitle),
                ),
              ),
              if (trailing case final trailing?) ...[
                const SizedBox(width: AppSpacing.space8),
                trailing,
              ],
            ],
          ),
          if (subtitle case final subtitle?) ...[
            const SizedBox(height: AppSpacing.space4),
            Text(subtitle, style: styles.formSupporting),
          ],
        ],
      ),
    );
  }
}
