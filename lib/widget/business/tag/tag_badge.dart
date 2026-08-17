import 'package:flutter/material.dart';

import 'package:smartflow/design_system/theme/app_text_styles.dart';
import 'package:smartflow/design_system/token/radius.dart';
import 'package:smartflow/design_system/token/spacing.dart';

class TagBadge extends StatelessWidget {
  const TagBadge({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Chip(
      label: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      labelStyle: context.appTextStyles.transactionBadge.copyWith(
        color: colors.onSurfaceVariant,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: colors.surfaceContainerHighest,
      side: BorderSide(color: colors.outlineVariant),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
      ),
    );
  }
}
