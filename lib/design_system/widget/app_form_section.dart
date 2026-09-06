import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../token/spacing.dart';
import 'app_surface.dart';

class AppFormSection extends StatelessWidget {
  const AppFormSection({
    required this.children,
    super.key,
    this.title,
    this.trailing,
    this.description,
    this.spacing = AppSpacing.space4,
    this.padding = const EdgeInsets.all(AppSpacing.space16),
    this.border = false,
  });

  final List<Widget> children;
  final String? title;
  final Widget? trailing;
  final String? description;
  final double spacing;
  final EdgeInsetsGeometry padding;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final description = this.description;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: context.appTextStyles.groupTitle),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.space8),
                  trailing!,
                ],
              ],
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: AppSpacing.space4),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space4,
              ),
              child: Text(
                description,
                style: context.appTextStyles.formSupporting,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.space8),
        ] else if (description != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
            child: Text(
              description,
              style: context.appTextStyles.formSupporting,
            ),
          ),
          const SizedBox(height: AppSpacing.space8),
        ],
        AppSurface(
          border: border,
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  if (index > 0) SizedBox(height: spacing),
                  children[index],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
