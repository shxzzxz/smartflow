import 'package:flutter/material.dart';

import 'package:smartflow/design_system/token/spacing.dart';

/// Internal geometry for finance labels that show category color as a dot.
///
/// Consumers keep business state to text and color mapping in their wrapper.
class FinanceDotLabel extends StatelessWidget {
  const FinanceDotLabel({
    required this.label,
    required this.dotColor,
    super.key,
  });

  final String label;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Chip(
      label: Text(label),
      avatar: Icon(Icons.circle, size: AppSpacing.space10, color: dotColor),
      visualDensity: VisualDensity.compact,
      backgroundColor: colors.surfaceContainerHighest,
      side: BorderSide(color: colors.outlineVariant),
    );
  }
}
