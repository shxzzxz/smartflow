import 'package:flutter/material.dart';

import '../../../core/time/date_label.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';

class FinanceActivityRow extends StatelessWidget {
  const FinanceActivityRow({
    required this.label,
    required this.occurredAt,
    required this.amountLabel,
    required this.icon,
    this.supportingText,
    this.onTap,
    super.key,
  });

  final String label;
  final DateTime occurredAt;
  final String amountLabel;
  final IconData icon;
  final String? supportingText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space12,
        vertical: AppSpacing.space10,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Center(child: Icon(icon, color: colors.primary, size: 24)),
          ),
          const SizedBox(width: AppSpacing.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label · ${formatDateLabel(occurredAt)}',
                  style: styles.formLabel,
                ),
                if (supportingText case final supporting?)
                  Text(
                    supporting,
                    style: styles.listSupporting.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.space8),
          SizedBox(
            width: 96,
            child: Text(
              amountLabel,
              style: styles.formLabel,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
    return onTap == null ? content : InkWell(onTap: onTap, child: content);
  }
}
