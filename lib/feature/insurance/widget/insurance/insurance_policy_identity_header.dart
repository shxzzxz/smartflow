import 'package:flutter/material.dart';

import '../../../../application/insurance/insurance_query_api.dart';
import '../../../../design_system/theme/app_text_styles.dart';
import '../../../../design_system/token/spacing.dart';
import '../../../../design_system/widget/app_status_badge.dart';
import '../../../../design_system/widget/app_surface.dart';
import '../../presentation/insurance_presentation.dart';
import 'insurance_category_icon.dart';

class InsurancePolicyIdentityHeader extends StatelessWidget {
  const InsurancePolicyIdentityHeader({
    required this.insurance,
    required this.status,
    super.key,
  });

  final CommercialInsurance insurance;
  final InsuranceCoverageStatus status;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    return AppSurface(
      border: true,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Row(
          children: [
            InsuranceCategoryIcon.commercial(
              category: insurance.category,
              size: AppSpacing.space48,
            ),
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          insurance.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: styles.subsectionTitleStrong,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space8),
                      AppStatusBadge(
                        presentation: insuranceStatusBadgePresentation(status),
                        size: AppStatusBadgeSize.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    '${insurance.insurerName} · '
                    '${insuranceCategoryDisplayLabel(insurance.category)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.listSupporting,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
