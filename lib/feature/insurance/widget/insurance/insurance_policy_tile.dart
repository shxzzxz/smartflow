import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../../application/insurance/insurance_query_api.dart';
import '../../../../design_system/theme/app_text_styles.dart';
import '../../../../design_system/token/spacing.dart';
import '../../../../design_system/widget/app_status_badge.dart';
import '../../presentation/insurance_presentation.dart';
import 'insurance_category_icon.dart';

class InsurancePolicyTile extends StatelessWidget {
  const InsurancePolicyTile({
    required this.insurance,
    required this.status,
    required this.onTap,
    super.key,
    this.insuredPeopleLabel,
    this.showInsuredPeople = false,
    this.showCoverageTerm = false,
    this.showAmount = true,
  });

  final CommercialInsurance insurance;
  final InsuranceCoverageStatus status;
  final String? insuredPeopleLabel;
  final VoidCallback onTap;
  final bool showInsuredPeople;
  final bool showCoverageTerm;
  final bool showAmount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final styles = context.appTextStyles;
    final coverageAmountLabel = insuranceCoverageAmountDisplayLabel(
      insurance.coverageAmount?.amount,
    );
    final subtitle = [
      insurance.insurerName,
      if (showAmount) '保额 $coverageAmountLabel',
    ].join(' · ');
    return InkWell(
      key: ValueKey('coverage-commercial-${insurance.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Row(
          children: [
            InsuranceCategoryIcon.commercial(category: insurance.category),
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          insurance.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: styles.listTitle,
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
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.listSupporting,
                  ),
                  if (showInsuredPeople) ...[
                    const SizedBox(height: AppSpacing.space4),
                    Text(
                      '被保险人：${insuredPeopleLabel ?? '未记录'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: styles.listSupporting,
                    ),
                  ],
                  if (showCoverageTerm) ...[
                    const SizedBox(height: AppSpacing.space4),
                    Text(
                      insuranceCoverageTermLabel(insurance.coverageTerm),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: styles.listSupporting,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.space4),
            Icon(
              RemixIcons.arrow_right_s_line,
              size: AppSpacing.space20,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
