import 'package:flutter/material.dart';

import '../../../../design_system/theme/app_text_styles.dart';
import '../../../../design_system/token/component.dart';
import '../../../../design_system/token/spacing.dart';

class InsuranceKeyValueRow extends StatelessWidget {
  const InsuranceKeyValueRow({
    required this.label,
    required this.value,
    super.key,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space16,
        vertical: AppSpacing.space12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: AppComponentTokens.keyValueLabelWidth,
            child: Text(label, style: styles.detailLabel),
          ),
          const SizedBox(width: AppSpacing.space12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: styles.detailValue,
            ),
          ),
        ],
      ),
    );
  }
}
