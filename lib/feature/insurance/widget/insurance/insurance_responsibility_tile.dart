import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../../application/insurance/insurance_query_api.dart';
import '../../../../design_system/theme/app_text_styles.dart';
import '../../../../design_system/token/spacing.dart';
import 'insurance_category_icon.dart';

class InsuranceResponsibilityTile extends StatelessWidget {
  const InsuranceResponsibilityTile({
    required this.responsibility,
    super.key,
    this.onTap,
  });

  final CoverageResponsibility responsibility;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final styles = context.appTextStyles;
    return InkWell(
      key: ValueKey('insurance-responsibility-${responsibility.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Row(
          children: [
            InsuranceCategoryIcon.responsibility(
              kind: responsibility.kind,
              size: AppSpacing.space40,
            ),
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    responsibility.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.listTitle,
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    responsibility.kind.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.listSupporting,
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.space8),
              Icon(
                RemixIcons.arrow_right_s_line,
                size: AppSpacing.space20,
                color: colors.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
