import 'package:flutter/material.dart';

import '../token/list.dart';
import '../token/spacing.dart';

/// Inset horizontal divider between rows inside one list surface.
class AppListDivider extends StatelessWidget {
  const AppListDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.space16),
      height: AppListTokens.dividerThickness,
      color: colors.outlineVariant.withValues(
        alpha: AppListTokens.dividerOpacity,
      ),
    );
  }
}
